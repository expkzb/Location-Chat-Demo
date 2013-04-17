/*!
 * \file    ChatViewController
 * \project 
 * \author  Andy Rifken 
 * \date    4/13/13.
 *
 */



#import <CoreLocation/CoreLocation.h>
#import "ChatViewController.h"
#import "ChatMessage.h"
#import "MapViewController.h"
#import "ChatNavigationController.h"
#import "ClientsViewController.h"


@implementation ChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];


    self.navigationItem.title = @"Chat";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Map" style:UIBarButtonItemStyleBordered target:self action:@selector(viewMapTapped:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clients" style:UIBarButtonItemStyleBordered target:self action:@selector(viewClientsTapped:)];


    self.messages = [[NSMutableArray alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];


    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];

    self.chatInputView = [[ChatInputView alloc] init];
    self.chatInputView.delegate = self;
    [self.view addSubview:self.chatInputView];

    NSDictionary *metrics = @{
            @"margin" : [NSNumber numberWithFloat:4.0]
    };

    UIView *tv = self.tableView;
    UIView *civ = self.chatInputView;

    tv.translatesAutoresizingMaskIntoConstraints = NO;
    civ.translatesAutoresizingMaskIntoConstraints = NO;

    NSMutableArray *layoutConstraints = [[NSMutableArray alloc] init];

    [layoutConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|[tv]|"
                                                                                   options:0
                                                                                   metrics:metrics
                                                                                     views:NSDictionaryOfVariableBindings(tv)]];

    [layoutConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|[civ]|"
                                                                                   options:0
                                                                                   metrics:metrics
                                                                                     views:NSDictionaryOfVariableBindings(civ)]];

    self.vertLayoutsNoKeyboard = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv(>=100)]-[civ]|"
                                                                         options:0
                                                                         metrics:metrics
                                                                           views:NSDictionaryOfVariableBindings(tv, civ)];

    [layoutConstraints addObjectsFromArray:self.vertLayoutsNoKeyboard];

    [self.view addConstraints:layoutConstraints];
}

- (void)viewClientsTapped:(id)viewClientsTapped {
    ClientsViewController *viewController = [[ClientsViewController alloc] init];
    [self presentViewController:viewController animated:YES completion:^{

    }];
}

- (void)viewMapTapped:(id)viewMapTapped {
    MapViewController *mapViewController = [[MapViewController alloc] init];
    mapViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
    [self presentViewController:mapViewController animated:YES completion:^{

    }];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -
#pragma mark Table View
//============================================================================================================

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.messages count];

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellID = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellID];
    }
    ChatMessage *message = [self.messages objectAtIndex:indexPath.row];

    BOOL isMe = ([message.clientId isEqualToString:[self myClientID]]);

    if (isMe) {
        cell.textLabel.text = message.text;
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
    } else {
        cell.textLabel.text = [NSString stringWithFormat:@"(%@) %@", message.clientId, message.text];
        cell.textLabel.textAlignment = NSTextAlignmentRight;
    }

    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ near %@", [message dateString], [message locationString]];
    return cell;
}

- (NSString *)myClientID {
    return [[(ChatNavigationController *) [self navigationController] connection] clientId];
}


- (void)reverseGeocodeMessage:(ChatMessage *)message {

    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    __weak ChatViewController *bself = self;
    [geocoder reverseGeocodeLocation:message.location completionHandler:^(NSArray *placemarks, NSError *error) {
        if (placemarks && [placemarks count] > 0 && !error) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            message.locationString = [NSString stringWithFormat:@"%@, %@", placemark.locality, placemark.administrativeArea];

            if ([bself.messages containsObject:message]) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[bself.messages indexOfObject:message] inSection:0];
                [bself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }
    }];
}

- (void)addMessage:(ChatMessage *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.messages addObject:message];
        [self reverseGeocodeMessage:message];
        [self.tableView reloadData];
    });
}

#pragma mark -
#pragma mark chat events
//============================================================================================================

- (void)chatInputView:(ChatInputView *)view didSendMessage:(NSString *)text {
    ChatMessage *message = [[ChatMessage alloc] init];
    message.text = text;
    message.clientId = [self myClientID];
    message.location = [(ChatNavigationController *) self.navigationController currentLocation];
    message.date = [NSDate date];

    NSLog(@"sending message: %@", message);
    [[(ChatNavigationController *) [self navigationController] connection] send:message];
}



#pragma mark -
#pragma mark keyboard
//============================================================================================================


- (void)keyboardWillShow:(NSNotification *)notification {
    UIView *tv = self.tableView;
    UIView *civ = self.chatInputView;
    CGFloat keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;

    self.vertLayoutsKeyboard = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv(>=100)]-[civ]-(keyboardHeight)-|"
                                                                       options:0
                                                                       metrics:@{@"keyboardHeight" : [NSNumber numberWithFloat:keyboardHeight]}
                                                                         views:NSDictionaryOfVariableBindings(tv, civ)];
    [self.view removeConstraints:self.vertLayoutsNoKeyboard];
    [self.view addConstraints:self.vertLayoutsKeyboard];
    [self.view invalidateIntrinsicContentSize];
}

- (void)keyboardWillHide:(NSNotification *)keyboardWillHide {
    [self.view removeConstraints:self.vertLayoutsKeyboard];
    [self.view addConstraints:self.vertLayoutsNoKeyboard];
    [self.view invalidateIntrinsicContentSize];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.isDragging) {
        [self.chatInputView.messageField resignFirstResponder];
    }
}


@end