//
//  ViewController.m
//  NetReachability
//
//  Created by Serhii Kyrylenko on 8/10/18.
//  Copyright © 2018 Delphi Software. All rights reserved.
//

#import "ViewController.h"
#import "Reachability.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel     *summaryLabel;
@property (weak, nonatomic) IBOutlet UITextField *remoteHostTextField;
@property (weak, nonatomic) IBOutlet UITextField *remoteHostStatusField;
@property (weak, nonatomic) IBOutlet UITextField *internetConnectionStatusField;
@property (weak, nonatomic) IBOutlet UITableView *logTable;
@property (weak, nonatomic) IBOutlet UISwitch *onlineStatusSwitch;

@property (strong, nonatomic) Reachability *hostReachability;
@property (strong, nonatomic) Reachability *internetReachability;

@property (strong, nonatomic) NSMutableArray<NSString *> *logFlagsArray;
@property (copy, nonatomic) NSString                     *remoteHostName;

@end

@interface ViewController (TableView)<UITableViewDataSource>
@end

@interface ViewController (TextField)<UITextFieldDelegate>
@end

extern NSString *klogKey;

@implementation ViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.logFlagsArray = [[NSMutableArray alloc] init];
    
    /*
     Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the method reachabilityChanged will be called.
     */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    //Change the host name here to change the server you want to monitor.
    self.remoteHostName = @"inspection-api.constructsecure.com";
    NSString *remoteHostLabelFormatString = NSLocalizedString(@"%@", @"Remote host label format string");
    self.remoteHostTextField.text = [NSString stringWithFormat:remoteHostLabelFormatString, self.remoteHostName];
    
    [self starHostNotifier];
    [self startInternetNotifier];
    
}


- (void)starHostNotifier {
    self.hostReachability = nil;
    self.hostReachability = [Reachability reachabilityWithHostName:self.remoteHostName];
    [self.hostReachability startNotifier];
    [self updateInterfaceWithReachability:self.hostReachability
                           additionalInfo:nil];
}

- (void)startInternetNotifier {
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    [self updateInterfaceWithReachability:self.internetReachability
                           additionalInfo:nil];
}


/*!
 * Called by Reachability whenever status changes.
 */
- (void) reachabilityChanged:(NSNotification *)notification {
    Reachability* currentReachability = [notification object];
    NSParameterAssert([currentReachability isKindOfClass:[Reachability class]]);
    
    NSString *additionalInfo = notification.userInfo[klogKey];
    [self updateInterfaceWithReachability:currentReachability
                           additionalInfo:additionalInfo];
}


- (void)updateInterfaceWithReachability:(Reachability *)reachability
                         additionalInfo:(NSString *) logInfo {
    if (logInfo) {
        [self.logFlagsArray insertObject:logInfo
                                 atIndex:0];
        NSIndexPath *indexPathToInsert = [NSIndexPath indexPathForRow:0
                                                            inSection:0];
        [self.logTable insertRowsAtIndexPaths:@[indexPathToInsert]
                             withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
    if (reachability == self.hostReachability) {
        [self configureTextField:self.remoteHostStatusField
                    reachability:reachability];
        
        BOOL connectionRequired = [reachability connectionRequired];

        NSString* baseLabelText = @"Unkown status";
        
        if (connectionRequired) {
            baseLabelText = NSLocalizedString(@"Connection required!\nCellular data network is available.", @"Reachability text if a connection is required");
        } else {
            baseLabelText = NSLocalizedString(@"Connection is established!\nCellular data network is active.", @"Reachability text if a connection is not required");
        }
        
        if ([reachability currentReachabilityStatus] == NotReachable) {
            baseLabelText = NSLocalizedString(@"Not Available", @"Text field text for access is not available");
        }
        
        self.onlineStatusSwitch.on = ([reachability currentReachabilityStatus] != NotReachable && !reachability.connectionRequired);
        
        self.summaryLabel.text = baseLabelText;
    } else if (reachability == self.internetReachability) {
        [self configureTextField:self.internetConnectionStatusField
                    reachability:reachability];
    }
    
}


- (void)configureTextField:(UITextField *)textField
              reachability:(Reachability *)reachability {
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    BOOL connectionRequired = [reachability connectionRequired];
    NSString* statusString = nil;
    
    switch (netStatus) {
        case NotReachable: {
            statusString = NSLocalizedString(@"Not Available", @"Text field text for access is not available");
            /*
             Minor interface detail- connectionRequired may return YES even when the host is unreachable. We cover that up here...
             */
            connectionRequired = NO;
            break;
        }
        case ReachableViaWWAN: {
            statusString = NSLocalizedString(@"Reachable WWAN", @"Text field text for access via WWAN");
            break;
        }
        case ReachableViaWiFi: {
            statusString= NSLocalizedString(@"Reachable WiFi", @"Text field text for access via WiFi");
            break;
        }
    }
    
    if (connectionRequired) {
        NSString *connectionRequiredFormatString = NSLocalizedString(@"%@, Connection Required", @"Concatenation of status string with connection requirement");
        statusString= [NSString stringWithFormat:connectionRequiredFormatString, statusString];
    }
    
    statusString = reachability == self.hostReachability ? [statusString stringByAppendingString:@" - Host"] : [statusString stringByAppendingString:@" - Internet"];
    textField.text= statusString;
}


@end


@implementation ViewController (TableView)

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cellIdentifier"];
    
    cell.textLabel.text = self.logFlagsArray[indexPath.row];
    
    return cell;
}


- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.logFlagsArray count];
}

@end


@implementation ViewController (TextField)

- (void)textFieldDidEndEditing:(UITextField *)textField {

}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    self.remoteHostName = textField.text;
    [textField resignFirstResponder];
    
    [self starHostNotifier];
    
    return YES;
}


@end
