
#import "NewLabelController.h"

#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

#import "AppKitExtras.h"
#import "Auth.h"
#import "DataStore.h"
#import "FoundationExtras.h"

static const CGFloat chooseColorAnimationDuration = 0.3f;

static NSColor *ShadowColorForTagColor(NSColor *color) {
    return [color blendedColorWithFraction:0.3 ofColor:[NSColor blackColor]];
}

static NSArray *GitHubColors() {
    return @[@"b60205",
             @"e99695",
             @"d93f0b",
             @"f9d0c4",
             @"fbca04",
             @"fef2c0",
             @"0e8a16",
             @"c2e0c6",
             @"006b75",
             @"bfdadc",
             @"1d76db",
             @"c5def5",
             @"0052cc",
             @"bfd4f2",
             @"5319e7",
             @"d4c5f9"];
}

@class ColorButton;

@interface NewLabelController ()

@property IBOutlet NSTextField *nameField;
@property IBOutlet NSTextField *repoOwnerAndName;
@property IBOutlet NSView *colorButtonsView;
@property IBOutlet NSTextField *nameAlreadyInUse;
@property IBOutlet NSButton *customColorButton;
@property IBOutlet NSButton *okButton;
@property IBOutlet NSProgressIndicator *progressIndicator;

- (void)colorButtonClicked:(ColorButton *)colorButton;

@end

@interface ColorButton : NSView

@property (nonatomic, assign) NSRect originalFrame;
@property (nonatomic, copy) NSString *colorString;
@property (nonatomic, weak) NewLabelController *controller;

@end

@implementation ColorButton

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithHexString:self.colorString] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [_controller colorButtonClicked:self];
}

@end


@implementation NewLabelController {
    NSString *_prefilledName;
    NSArray *_allLabels;
    NSString *_owner;
    NSString *_repo;
    BOOL _requestPending;
    NSDictionary *_createdLabel;
    NSColor *_color;
    CATextLayer *_tag;
    BOOL _finishTagAnimationScheduled;
}

- (instancetype)initWithPrefilledName:(NSString *)prefilledName
                            allLabels:(NSArray *)allLabels
                                owner:(NSString *)owner
                                 repo:(NSString *)repo {
    if (self = [super initWithWindowNibName:@"NewLabelController"]) {
        _prefilledName = prefilledName;
        _allLabels = allLabels;
        _owner = owner;
        _repo = repo;
        _color = [self defaultColor];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(customColorChanged:)
                                                     name:NSColorPanelColorDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib {
    NSArray *githubColors = GitHubColors();
    const CGFloat colorButtonWidth = 39;
    const CGFloat colorButtonHeight = 39;
    const CGFloat mouseOverExpandBy = 5;

    for (NSInteger i = 0; i < githubColors.count; i++) {
        NSRect frame = NSMakeRect(colorButtonWidth * (i / 2),
                                  mouseOverExpandBy + ((i % 2 == 0) ? colorButtonHeight : 0),
                                  colorButtonWidth,
                                  colorButtonHeight);
        ColorButton *button = [[ColorButton alloc] initWithFrame:frame];
        button.colorString = githubColors[i];
        button.controller = self;
        button.originalFrame = frame;
        [self.colorButtonsView addSubview:button];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controlTextDidChange:)
                                                 name:NSControlTextDidChangeNotification
                                               object:self.nameField];

    self.nameField.stringValue = _prefilledName;

    NSMutableAttributedString *str = [_customColorButton.attributedTitle mutableCopy];
    [str addAttribute:NSForegroundColorAttributeName
                value:[NSColor extras_controlBlue]
                range:NSMakeRange(0, str.length)];
    _customColorButton.attributedTitle = str;

    _repoOwnerAndName.stringValue = [NSString stringWithFormat:@"%@/%@", _owner, _repo];

    _tag = [CATextLayer layer];
    _tag.contentsScale = self.window.screen.backingScaleFactor;
    // Anchor right around the hole in the tag.
    _tag.anchorPoint = CGPointMake(0.17, 0.73);
    _tag.frame = CGRectMake(0, 0, 128 / 2.0, 112 / 2.0);
    _tag.string = @"\uf02b";
    _tag.font = CFBridgingRetain([NSFont fontWithName:@"FontAwesome" size:0.0]);
    _tag.fontSize = 60.0;
    _tag.alignmentMode = kCAAlignmentLeft;
    _tag.position = CGPointMake(55, 255);
    _tag.transform = CATransform3DMakeScale(0.8, 0.8, 1.0);
    _tag.shadowOpacity = 0.75;
    _tag.shadowRadius = 0.0;
    _tag.shadowOffset = CGSizeMake(0, -3);
    _tag.foregroundColor = [_color CGColor];
    _tag.shadowColor = [ShadowColorForTagColor(_color) CGColor];

    [self.window.contentView.layer addSublayer:_tag];

    // Prevent the pre-filled name from appearing highlighted / selected by default.
    [self.nameField becomeFirstResponder];
    [[self.nameField currentEditor] setSelectedRange:NSMakeRange(self.nameField.stringValue.length, 0)];
    
    [self updateUI];
}

- (void)updateUI {
    NSString *nameTrimmed = [self.nameField.stringValue stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
    NSArray *names = [_allLabels arrayByMappingObjects:^(NSDictionary *label) {
        return label[@"name"];
    }];
    BOOL nameIsUnique = ![names containsObject:nameTrimmed];

    if (_requestPending) {
        [_progressIndicator startAnimation:nil];
        _okButton.hidden = YES;
    } else {
        [_progressIndicator stopAnimation:nil];
        _okButton.hidden = NO;
    }

    _nameAlreadyInUse.hidden = nameIsUnique;
    self.okButton.enabled = (nameTrimmed.length > 0) && nameIsUnique;
}

- (void)customColorChanged:(NSNotification *)note {
    NSColorPanel *colorPanel = (NSColorPanel *)note.object;
    _color = colorPanel.color;
    [self beginTagAnimationToColor:_color];
}

- (void)controlTextDidChange:(NSNotification *)note {
    [self updateUI];
}

- (IBAction)cancelButtonClicked:(id)sender {
    [[NSColorPanel sharedColorPanel] close];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)okButtonClicked:(id)sender {
    [[NSColorPanel sharedColorPanel] close];
    _requestPending = YES;
    [self updateUI];

    NSDictionary *label = @{@"name" : [self.nameField.stringValue
                                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]],
                            @"color" : [_color hexString],
                            };

    __weak typeof(self) weakSelf = self;
    [[DataStore activeStore] addLabel:label
                            repoOwner:_owner
                             repoName:_repo
                           completion:
     ^(NSDictionary *createdLabel, NSError *error){
         typeof(self) strongSelf = weakSelf;
         if (strongSelf) {
             if (createdLabel) {
                 strongSelf->_createdLabel = createdLabel;
                 [strongSelf.window.sheetParent endSheet:strongSelf.window returnCode:NSModalResponseOK];
             } else {
                 _requestPending = NO;
                 [strongSelf updateUI];

                 NSAlert *alert = [NSAlert alertWithError:error];
                 [alert beginSheetModalForWindow:strongSelf.window completionHandler:nil];
             }
         }
     }];
}

- (void)beginTagAnimationToColor:(NSColor *)color {
    __weak typeof(self) weakSelf = self;

    [NSAnimationContext runAnimationGroup:
     ^(NSAnimationContext *context){
         context.allowsImplicitAnimation = YES;
         context.duration = chooseColorAnimationDuration / 2.0;
         _tag.foregroundColor = [color CGColor];
         _tag.shadowColor = [ShadowColorForTagColor(color) CGColor];
         _tag.transform = CATransform3DIdentity;
     }
                        completionHandler:
     ^{
         // If someone clicks the mouse down inside the color panel and
         // then drags around to cycle thru many colors, we want the tag to stay
         // englarged for as long as the user keeps dragging.  Only once the
         // mouse is released should we shrink the tag again.
         //
         // The following has this effect.  When the user is clicking and
         // dragging in the color panel, the run loop does not cycle for as
         // long as the mouse is down.  So, we can get our desired effect by
         // not shrinking the tag until the run loop starts moving again.
         typeof(self) strongSelf = weakSelf;
         if (strongSelf) {
             if (!strongSelf->_finishTagAnimationScheduled) {
                 strongSelf->_finishTagAnimationScheduled = YES;
                 CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
                     [weakSelf finishTagAnimation];
                 });
             }
         }
     }];
}

- (void)finishTagAnimation {
    _finishTagAnimationScheduled = NO;
    [NSAnimationContext runAnimationGroup:
     ^(NSAnimationContext *context){
         context.allowsImplicitAnimation = YES;
         context.duration = chooseColorAnimationDuration / 2.0;
         _tag.transform = CATransform3DMakeScale(0.8, 0.8, 1.0);
     }
                        completionHandler:nil];
}

- (void)colorButtonClicked:(ColorButton *)colorButton {
    _color = [NSColor colorWithHexString:colorButton.colorString];
    [self beginTagAnimationToColor:_color];

    // Bring to front so siblings don't obscure us.
    NSView *superview = colorButton.superview;
    [colorButton removeFromSuperview];
    [superview addSubview:colorButton];

    CGRect originalFrame = colorButton.originalFrame;
    CGRect animateToFrame = CGRectInset(originalFrame, -5, -5);

    [NSAnimationContext runAnimationGroup:
     ^(NSAnimationContext *context){
         context.duration = chooseColorAnimationDuration / 2.0;
         [[colorButton animator] setFrame:animateToFrame];
     }
                        completionHandler:
     ^{
         [NSAnimationContext runAnimationGroup:
          ^(NSAnimationContext *context){
              context.duration = chooseColorAnimationDuration / 2.0;
              [[colorButton animator] setFrame:originalFrame];
          }
                             completionHandler:nil];
     }];

    [self updateUI];
}

- (IBAction)customColorClicked:(id)sender {
    [[NSColorPanel sharedColorPanel] orderFront:nil];
}

/**
 Pick a random color from GitHub's 16-color palette that's not already
 in use by another label.  If all are in use, pick a random color.
 */
- (NSColor *)defaultColor {
    NSArray *colorsInUse = [_allLabels arrayByMappingObjects:^(NSDictionary *label) {
        return label[@"color"];
    }];

    NSMutableArray *shuffledGithubColors = [GitHubColors() mutableCopy];
    for (NSInteger i = shuffledGithubColors.count - 1; i > 0; i--) {
        NSInteger j = arc4random_uniform((uint32_t)i + 1);
        [shuffledGithubColors exchangeObjectAtIndex:i withObjectAtIndex:j];
    }

    for (NSString *colorString in shuffledGithubColors) {
        if (![colorsInUse containsObject:colorString]) {
            return [NSColor colorWithHexString:colorString];
        }
    }

    return [NSColor colorWithHue:(CGFloat)arc4random() / UINT32_MAX
                      saturation:1.0
                      brightness:1.0
                           alpha:1.0];
}

@end
