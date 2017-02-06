//
//  NewProjectController.m
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NewProjectController.h"

#import "DataStore.h"
#import "Extras.h"
#import "MetadataStore.h"
#import "Project.h"
#import "Repo.h"
#import "ProgressSheet.h"

@interface NewProjectController ()

@property (strong) Repo *repo;

@property IBOutlet NSTextField *nameField;
@property IBOutlet NSTextView *bodyView;
@property IBOutlet NSTextField *existsLabel;

@property IBOutlet NSButton *createButton;
@property IBOutlet NSButton *cancelButton;

@property NSArray *existingProjects;

@property (copy) void (^completion)(Project *, NSError *error);

@end

@implementation NewProjectController

- (NSString *)windowNibName { return @"NewProjectController"; }

- (id)initWithRepo:(Repo *)repo {
    NSParameterAssert(repo);
    
    if (self = [super init]) {
        _repo = repo;
        
        MetadataStore *ms = [[DataStore activeStore] metadataStore];
        _existingProjects = [ms projectsForRepo:repo];
    }
    return self;
}

- (id)initWithOrg:(Account *)org {
    NSParameterAssert(org);
    NSParameterAssert(org.accountType == AccountTypeOrg);
    
    if (self = [super init]) {
        _org = org;
        
        MetadataStore *ms = [[DataStore activeStore] metadataStore];
        _existingProjects = [ms projectsForOrg:org];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self validateUI];
}

- (void)validateUI {
    NSString *name = [_nameField.stringValue trim];
    BOOL exists = [_existingProjects containsObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"name =[cd] %@", name]];
    _existsLabel.hidden = !exists;
    _createButton.enabled = name.length > 0 && !exists;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self validateUI];
}

- (IBAction)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    [self finishWithProject:nil error:nil];
}

- (IBAction)create:(id)sender {
    NSWindow *sheetParent = self.window.sheetParent;
    [sheetParent endSheet:self.window];
    
    ProgressSheet *progressSheet = [ProgressSheet new];
    progressSheet.message = NSLocalizedString(@"Creating Project", nil);
    [progressSheet beginSheetInWindow:sheetParent];
    
    NSString *projName = [_nameField.stringValue trim];
    NSString *projBody = [_bodyView.textStorage.string trim];
    
    void (^completion)(Project *, NSError *) = ^(Project *proj, NSError *error) {
        [progressSheet endSheet];
        if (error) {
            NSAlert *err = [NSAlert new];
            err.messageText = NSLocalizedString(@"Unable to create project", nil);
            err.informativeText = [error localizedDescription];
            [err beginSheetModalForWindow:sheetParent completionHandler:^(NSModalResponse returnCode) {
                [self finishWithProject:nil error:error];
            }];
        } else {
            [self finishWithProject:proj error:nil];
        }
    };
    
    DataStore *store = [DataStore activeStore];
    if (_repo) {
        [store addProjectNamed:projName body:projBody inRepo:_repo completion:completion];
    } else {
        [store addProjectNamed:projName body:projBody inOrg:_org completion:completion];
    }
}

- (void)finishWithProject:(Project *)proj error:(NSError *)error {
    CFRelease((__bridge CFTypeRef)self); // break retain cycle started in beginInWindow.
    
    if (_completion) {
        _completion(proj, error);
    }
}

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(Project *, NSError *error))completion
{
    NSParameterAssert(parentWindow);
    
    CFRetain((__bridge CFTypeRef)self); // create a retain cycle until we finish
    self.completion = completion;
    
    NSWindow *window = self.window;
    [parentWindow beginSheet:window completionHandler:nil];
}

@end
