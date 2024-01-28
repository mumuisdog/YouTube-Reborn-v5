#import "ReorderPivotBarController.h"
#import "Localization.h"

@interface ReorderPivotBarController ()
@end

@implementation ReorderPivotBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = LOC(@"REORDER_TABS");

    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    UIBarButtonItem *resetButton = [[UIBarButtonItem alloc] initWithTitle:LOC(@"RESET_TEXT") style:UIBarButtonItemStylePlain target:self action:@selector(reset)];
    self.navigationItem.leftBarButtonItems = resetButton;
    self.navigationItem.rightBarButtonItem = doneButton;

    UITableViewStyle style;
    if (@available(iOS 13, *)) {
        style = UITableViewStyleInsetGrouped;
    } else {
        style = UITableViewStyleGrouped;
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:style];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.tableView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.tableView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [self.tableView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor]
    ]];

    NSArray *savedTabOrder = [[NSUserDefaults standardUserDefaults] objectForKey:@"kTabOrder"];
    if (savedTabOrder != nil) {
        self.tabOrder = [NSMutableArray arrayWithArray:savedTabOrder];

        UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self.tableView addGestureRecognizer:longPressGesture];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"TabBarTableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight) {
            cell.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
            cell.textLabel.textColor = [UIColor blackColor];
            cell.detailTextLabel.textColor = [UIColor blackColor];
        } else {
            cell.backgroundColor = [UIColor colorWithRed:0.110 green:0.110 blue:0.118 alpha:1.0];
            cell.textLabel.textColor = [UIColor whiteColor];
            cell.textLabel.shadowColor = [UIColor blackColor];
            cell.textLabel.shadowOffset = CGSizeMake(1.0, 1.0);
            cell.detailTextLabel.textColor = [UIColor whiteColor];
        }
    }

    if (indexPath.section == 0) {
        NSString *tabIdentifier = self.tabOrder[indexPath.row];
        cell.textLabel.text = tabIdentifier;

        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSInteger sourceIndex = sourceIndexPath.row;
    NSInteger destinationIndex = destinationIndexPath.row;

    NSString *tabIdentifier = self.tabOrder[sourceIndex];
    [self.tabOrder removeObjectAtIndex:sourceIndex];
    [self.tabOrder insertObject:tabIdentifier atIndex:destinationIndex];
}

- (void)reorderTabs {
    NSMutableArray *newTabOrder = [NSMutableArray array];  
    NSArray *tabOrderKeys = @[
        @"FEwhat_to_watch",
        @"FEshorts",
        @"FEuploads",
        @"FEsubscriptions",
        @"FElibrary"
    ];
    for (NSString *tabKey in tabOrderKeys) {
        for (YTIPivotBarSupportedRenderers *item in self.tabOrder) {
            if ([[[item pivotBarItemRenderer] pivotIdentifier] isEqualToString:tabKey]) {
                [newTabOrder addObject:item];
                break;
            }
        }
    }
    self.tabOrder = newTabOrder;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
        if (indexPath && indexPath.section == 0) {
            [self.tableView setEditing:YES animated:YES];
            NSInteger sourceIndex = indexPath.row;
            NSInteger destinationIndex = [self.tableView numberOfRowsInSection:0] - 1;
            NSIndexPath *destinationIndexPath = [NSIndexPath indexPathForRow:destinationIndex inSection:0];
            [self.tableView moveRowAtIndexPath:indexPath toIndexPath:destinationIndexPath];
        }
    }
}

- (void)reset {
    self.tabOrder = [@[
        @"FEwhat_to_watch",
        @"FEshorts",
        @"FEuploads",
        @"FEsubscriptions",
        @"FElibrary"
    ] mutableCopy];
    [self.tableView reloadData];
    [self save];
}

- (void)done {
    [self reorderTabs];
    [self save];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
