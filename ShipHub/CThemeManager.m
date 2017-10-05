//
//  CThemeManager.m
//  Ship
//
//  Created by James Howard on 10/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "CThemeManager.h"

#import "Extras.h"

NSString *const CThemeDidChangeNotification = @"CThemeDidChangeNotification";

static NSString *ThemeBackgroundKey = @"DVTSourceTextBackground";
static NSString *ThemeSelectionKey = @"DVTSourceTextSelectionColor";
static NSString *ThemeLineSpacingKey = @"DVTLineSpacing";
static NSString *ThemeColorsKey = @"DVTSourceTextSyntaxColors";
static NSString *ThemeFontsKey = @"DVTSourceTextSyntaxFonts";
static NSString *ThemePlainKey = @"xcode.syntax.plain";

/*
 Theme CSS Vars:
 :root {
 --ctheme-background-color:
 --ctheme-background-color-codeblock: #F7F7F7 if --ctheme-background-color is white, else --ctheme-background-color
 --ctheme-background-color-spacer: #EEE if ctheme-background-color is light, #333 otherwise
 --ctheme-background-color-inserted: #E0FFDF if ctheme-background-color is light, #1B5018 otherwise
 --ctheme-background-color-deleted: #FFEDED if ctheme-background-color is light, #520F0F otherwise
 --ctheme-background-color-changed: #E7EEFF light, #33254F otherwise
 --ctheme-background-color-char-changed: #FBE4C8 light, #503B7C otherwise
 --ctheme-selection-color:
 --ctheme-font-family:
 --ctheme-font-size:
 --ctheme-line-height:
 
 --ctheme-gutter-font-size:
 --ctheme-gutter-background-color: #F7F7F7 | #080808
 --ctheme-gutter-color: #BBB | #444
 --ctheme-gutter-commentable-color: #737373 | #8C8C8C
 --ctheme-gutter-navigable-color: #737373 | #8C8C8C
 --ctheme-gutter-border-left: 1px solid #B3B3B3 | 1px solid #4C4C4C
 --ctheme-gutter-border-right: 1px solid #E7E7E7 | 1px solid #181818
 
 --ctheme-minimap-background-color: #DEDEDE | #212121
 
 --ctheme-color-xcode-syntax-attribute:
 --ctheme-color-xcode-syntax-character:
 --ctheme-color-xcode-syntax-comment:
 --ctheme-color-xcode-syntax-comment-doc:
 --ctheme-color-xcode-syntax-comment-doc-keyword:
 --ctheme-color-xcode-syntax-identifier-class:
 --ctheme-color-xcode-syntax-identifier-class-system:
 --ctheme-color-xcode-syntax-identifier-constant:
 --ctheme-color-xcode-syntax-identifier-constant-system:
 --ctheme-color-xcode-syntax-identifier-function:
 --ctheme-color-xcode-syntax-identifier-function-system:
 --ctheme-color-xcode-syntax-identifier-macro:
 --ctheme-color-xcode-syntax-identifier-macro-system:
 --ctheme-color-xcode-syntax-identifier-type:
 --ctheme-color-xcode-syntax-identifier-type-system:
 --ctheme-color-xcode-syntax-identifier-variable:
 --ctheme-color-xcode-syntax-identifier-variable-system:
 --ctheme-color-xcode-syntax-keyword:
 --ctheme-color-xcode-syntax-number:
 --ctheme-color-xcode-syntax-plain:
 --ctheme-color-xcode-syntax-preprocessor:
 --ctheme-color-xcode-syntax-string:
 --ctheme-color-xcode-syntax-url:
 }
*/
 

@implementation CThemeManager {
    NSString *_xcodeThemesPath;
    NSString *_loadedThemeName;
}

static CThemeManager *sManager;

+ (CThemeManager *)sharedManager {
    if (!sManager) {
        return [[CThemeManager alloc] init];
    }
    return sManager;
}

- (id)init {
    if (self = [super init]) {
        if (!sManager) sManager = self;
        [self discoverXcodeThemesPath];
        [self loadTheme];
    }
    return self;
}

- (NSString *)selectedTheme {
    NSUserDefaults *myDefaults = [NSUserDefaults standardUserDefaults];
    NSString *myThemeName = [myDefaults stringForKey:@"CThemeName"];
    
    if (!myThemeName) {
        // see if Xcode has a theme set
        myThemeName = (__bridge_transfer NSString *) CFPreferencesCopyAppValue(CFSTR("XCFontAndColorCurrentTheme"), CFSTR("com.apple.dt.Xcode.plist"));
    }
    
    return myThemeName ?: @"Default.xccolortheme";
}

- (double)themeSizeMultiplier {
    double m = [[NSUserDefaults standardUserDefaults] doubleForKey:@"CThemeSizeMultiplier"];
    if (m < 0.2) {
        m = 1.0;
    }
    if (m > 10.0) {
        m = 1.0;
    }
    return m;
}

- (void)discoverXcodeThemesPath {
    NSString *xcodeAppPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Xcode"];
    _xcodeThemesPath = [xcodeAppPath stringByAppendingPathComponent:@"Contents/SharedFrameworks/DVTKit.framework/Resources/FontAndColorThemes/"];
}

- (NSString *)userThemesPath {
    return [@"~/Library/Developer/Xcode/UserData/FontAndColorThemes" stringByExpandingTildeInPath];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    menu.autoenablesItems = NO;
    
    NSString *userThemesPath = [self userThemesPath];
    NSString *selectedTheme = [self selectedTheme];
    
    NSFileManager *fileman = [NSFileManager defaultManager];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"SELF endswith '.xccolortheme'"];
    NSArray *userThemes = [[fileman contentsOfDirectoryAtPath:userThemesPath error:NULL] filteredArrayUsingPredicate:filter];
    NSArray *appThemes = _xcodeThemesPath ? [[fileman contentsOfDirectoryAtPath:_xcodeThemesPath error:NULL] filteredArrayUsingPredicate:filter] : nil;
    
    NSMutableSet *seenThemes = [NSMutableSet new];
    
    [menu removeAllItems];
    
    if ([userThemes count] != 0) {
        NSMenuItem *item = [menu addItemWithTitle:NSLocalizedString(@"User Themes", nil) action:nil keyEquivalent:@""];
        item.enabled = NO;
        
        for (NSString *themeName in userThemes) {
            item = [menu addItemWithTitle:[themeName stringByDeletingPathExtension] action:@selector(switchTheme:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = themeName;
            if ([themeName isEqualToString:selectedTheme]) {
                item.state = NSOnState;
            }
            [seenThemes addObject:themeName];
        }
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    if ([appThemes count] != 0) {
        NSMenuItem *item = [menu addItemWithTitle:NSLocalizedString(@"Xcode Themes", nil) action:nil keyEquivalent:@""];
        item.enabled = NO;
        
        for (NSString *themeName in appThemes) {
            if ([seenThemes containsObject:themeName]) {
                continue;
            }
            
            item = [menu addItemWithTitle:[themeName stringByDeletingPathExtension] action:@selector(switchTheme:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = themeName;
            if ([themeName isEqualToString:selectedTheme]) {
                item.state = NSOnState;
            }
            [seenThemes addObject:themeName];
        }
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    if (![seenThemes containsObject:@"Default.xccolortheme"]) {
        NSMenuItem *item = [menu addItemWithTitle:@"Default" action:@selector(switchTheme:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = @"Default.xccolortheme";
        if ([@"Default.xccolortheme" isEqualToString:selectedTheme]) {
            item.state = NSOnState;
        }
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    // add a font size menu item
    NSMenuItem *sizeItem = [menu addItemWithTitle:NSLocalizedString(@"Font Size", nil) action:nil keyEquivalent:@""];
    NSMenu *sizeMenu = [NSMenu new];
    sizeItem.submenu = sizeMenu;
    {
        double currentMultiplier = [self themeSizeMultiplier];
        NSMenuItem *incr = [sizeMenu addItemWithTitle:NSLocalizedString(@"Increase", nil) action:@selector(makeTextLarger:) keyEquivalent:@""];
        incr.target = self;
        incr.enabled = currentMultiplier < 10.0;
        NSMenuItem *decr = [sizeMenu addItemWithTitle:NSLocalizedString(@"Decrease", nil) action:@selector(makeTextSmaller:) keyEquivalent:@""];
        decr.target = self;
        decr.enabled = currentMultiplier > 0.3;
        [sizeMenu addItem:[NSMenuItem separatorItem]];
        NSMenuItem *reset = [sizeMenu addItemWithTitle:NSLocalizedString(@"Reset", nil) action:@selector(makeTextStandardSize:) keyEquivalent:@""];
        reset.target = self;
        reset.enabled = currentMultiplier != 1.0;
    }
}

- (IBAction)switchTheme:(id)sender {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setObject:[sender representedObject] forKey:@"CThemeName"];
    [def setDouble:1.0 forKey:@"CThemeSizeMultiplier"];
    [self loadTheme];
    [[NSNotificationCenter defaultCenter] postNotificationName:CThemeDidChangeNotification object:self];
}

- (IBAction)makeTextLarger:(id)sender {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    double cur = [self themeSizeMultiplier];
    cur *= 1.25;
    [def setDouble:cur forKey:@"CThemeSizeMultiplier"];
    [self loadTheme];
    [[NSNotificationCenter defaultCenter] postNotificationName:CThemeDidChangeNotification object:self];
}
                                
- (IBAction)makeTextSmaller:(id)sender {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    double cur = [self themeSizeMultiplier];
    cur *= 0.8;
    [def setDouble:cur forKey:@"CThemeSizeMultiplier"];
    [self loadTheme];
    [[NSNotificationCenter defaultCenter] postNotificationName:CThemeDidChangeNotification object:self];
}

- (IBAction)makeTextStandardSize:(id)sender {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setDouble:1.0 forKey:@"CThemeSizeMultiplier"];
    [self loadTheme];
    [[NSNotificationCenter defaultCenter] postNotificationName:CThemeDidChangeNotification object:self];
}

static NSColor *parseColor(NSString *xcodeColor, NSColor *fallback) {
    NSArray *comps = [xcodeColor componentsSeparatedByString:@" "];
    if (comps.count != 4) return fallback;
    return [NSColor colorWithRed:[comps[0] doubleValue] green:[comps[1] doubleValue] blue:[comps[2] doubleValue] alpha:[comps[3] doubleValue]];
}

static NSString *cssColor(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    CGFloat r, g, b, a;
    [rgb getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"rgb(%.0f, %.0f, %.0f)", r*255.0, g*255.0, b*255.0];
}

static NSString *cssFontFamily(NSString *primaryFontFamily) {
    return [NSString stringWithFormat:@"\"%@\", menlo, monospace", primaryFontFamily];
}

static BOOL parseFont(NSString *fontStr, NSString *__autoreleasing* fontFamily, double *fontSize) {
    static dispatch_once_t onceToken;
    static NSRegularExpression *re;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"^(.*) - (\\d+(?:\\.\\d+)?)$" options:0 error:NULL];
    });
    NSTextCheckingResult *r = [re firstMatchInString:fontStr options:0 range:NSMakeRange(0, fontStr.length)];
    if (!r) {
        return NO;
    }
    
    if (fontFamily) *fontFamily = [fontStr substringWithRange:[r rangeAtIndex:1]];
    if (fontSize) *fontSize = [[fontStr substringWithRange:[r rangeAtIndex:2]] doubleValue];
    
    return YES;
}

- (void)loadThemeAtPath:(NSString *)themePath {
    NSData *plistData = [NSData dataWithContentsOfFile:themePath];
    
    if (!plistData) {
        ErrLog(@"Unable to read theme");
        [self loadDefaultTheme];
        return;
    }
    
    NSDictionary *theme = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:NULL error:NULL];
    
    if (!theme) {
        ErrLog(@"Unable to load theme plist");
        [self loadDefaultTheme];
        return;
    }
    
    double sizeMultiplier = [self themeSizeMultiplier];
    
    NSColor *backgroundColor = parseColor(theme[ThemeBackgroundKey], [NSColor whiteColor]);
    NSColor *selectionColor = parseColor(theme[ThemeSelectionKey], [NSColor selectedTextBackgroundColor]);
    
    NSString *plainFont = theme[ThemeFontsKey][ThemePlainKey];
    NSString *plainFontFamily = nil;
    double plainFontSize = 11.0;
    if (!parseFont(plainFont, &plainFontFamily, &plainFontSize)) {
        ErrLog(@"Unable to parse font: %@", plainFont);
        [self loadDefaultTheme];
        return;
    }
    
    plainFontSize = MAX(round(plainFontSize * sizeMultiplier), 5.0);
    double lineHeight = round(plainFontSize * 1.2);
    
    NSMutableDictionary *vars = [NSMutableDictionary new];
    
    vars[@"--ctheme-background-color"] = cssColor(backgroundColor);
    
    CGFloat bgLuma = [backgroundColor luma];
    if (bgLuma < 0.9) {
        // if the color is not very white, use the background color for codeblocks
        vars[@"--ctheme-background-color-codeblock"] = cssColor(backgroundColor);
    } else {
        // else use this gray color for codeblock background
        vars[@"--ctheme-background-color-codeblock"] = @"#F7F7F7";
    }
    
    NSColor *spacerColor;
    if (bgLuma < 0.05) {
        // black background
        spacerColor = [NSColor colorWithHexString:@"333"];
    } else if (bgLuma < 0.5) {
        // dark background. Use a slightly lighter color for spacer.
        spacerColor = [backgroundColor colorByAdjustingBrightness:1.25];
    } else if (bgLuma < 0.95) {
        // slightly darker
        spacerColor = [backgroundColor colorByAdjustingBrightness:0.8];
    } else {
        // white background, use specifically this spacer color
        spacerColor = [NSColor colorWithHexString:@"EEE"];
    }
    vars[@"--ctheme-background-color-spacer"] = cssColor(spacerColor);
    
    if (bgLuma < 0.5) {
        vars[@"--ctheme-background-color-inserted"] = @"#1B5018";
        vars[@"--ctheme-background-color-deleted"] = @"#520F0F";
        vars[@"--ctheme-background-color-changed"] = @"#33254F";
        vars[@"--ctheme-background-color-char-changed"] = @"#503B7C";
        
        vars[@"--ctheme-gutter-background-color"] = @"#080808";
        vars[@"--ctheme-gutter-color"] = @"#444";
        vars[@"--ctheme-gutter-commentable-color"] = @"#8C8C8C";
        vars[@"--ctheme-gutter-navigable-color"] = @"#8C8C8C";
        vars[@"--ctheme-gutter-border-left"] = @"1px solid #4C4C4C";
        vars[@"--ctheme-gutter-border-right"] = @"1px solid #181818";
        
        vars[@"--ctheme-minimap-background-color"] = @"#212121";
        vars[@"--ctheme-minimap-visible-region-color"] = @"rgba(255, 255, 255, 0.2)";
    } else {
        vars[@"--ctheme-background-color-inserted"] = @"#E0FFDF";
        vars[@"--ctheme-background-color-deleted"] = @"#FFEDED";
        vars[@"--ctheme-background-color-changed"] = @"#E7EEFF";
        vars[@"--ctheme-background-color-char-changed"] = @"#FBE4C8";
        
        vars[@"--ctheme-gutter-background-color"] = @"#F7F7F7";
        vars[@"--ctheme-gutter-color"] = @"#BBB";
        vars[@"--ctheme-gutter-commentable-color"] = @"#737373";
        vars[@"--ctheme-gutter-navigable-color"] = @"#737373";
        vars[@"--ctheme-gutter-border-left"] = @"1px solid #B3B3B3";
        vars[@"--ctheme-gutter-border-right"] = @"1px solid #E7E7E7";
        
        vars[@"--ctheme-minimap-background-color"] = @"#DEDEDE";
        vars[@"--ctheme-minimap-visible-region-color"] = @"rgba(0, 0, 0, 0.2)";
    }
    
    vars[@"--ctheme-selection-color"] = cssColor(selectionColor);
    
    vars[@"--ctheme-font-family"] = cssFontFamily(plainFontFamily);
    vars[@"--ctheme-font-size"] = [NSString stringWithFormat:@"%.0fpx", plainFontSize];
    vars[@"--ctheme-line-height"] = [NSString stringWithFormat:@"%.0fpx", lineHeight];
    vars[@"--ctheme-gutter-font-size"] = [NSString stringWithFormat:@"%.0fpx", plainFontSize-1.0];
    
    NSDictionary *themeColors = theme[ThemeColorsKey];
    for (NSString *xcodeTokenType in themeColors) {
        NSString *varName = [NSString stringWithFormat:@"--ctheme-color-%@", [xcodeTokenType stringByReplacingOccurrencesOfString:@"." withString:@"-"]];
        NSColor *color = parseColor(themeColors[xcodeTokenType], [NSColor blackColor]);
        vars[varName] = cssColor(color);
    }
    
    DebugLog(@"Loaded theme at path: %@:\n%@", themePath, vars);
    _activeThemeVariables = vars;
}

- (void)loadDefaultTheme {
    [self loadThemeAtPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"Default" ofType:@"xccolortheme"]];
}

- (void)loadTheme {
    NSString *myThemeName = [self selectedTheme];
    
    // See if we can find the theme. It will live in one of these locations:
    // ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    // Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Resources/FontAndColorThemes/
    // ${APP_BUNDLE}/Contents/Resources/
    
    NSString *door1 = [[self userThemesPath] stringByAppendingPathComponent:myThemeName];
    NSFileManager *fileman = [NSFileManager defaultManager];
    if ([fileman fileExistsAtPath:door1]) {
        [self loadThemeAtPath:door1];
        return;
    }
    
    if (_xcodeThemesPath) {
        NSString *door2 = [_xcodeThemesPath stringByAppendingPathComponent:myThemeName];
        if ([fileman fileExistsAtPath:door2]) {
            [self loadThemeAtPath:door2];
            return;
        }
    }
    
    // still here, choose door 3 and load default theme
    [self loadDefaultTheme];
}

@end
