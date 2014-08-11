//
//  QMFriendsListDataSource.m
//  Q-municate
//
//  Created by Andrey Ivanov on 4/3/14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMFriendsListDataSource.h"
#import "QMUsersService.h"
#import "QMFriendListCell.h"
#import "QMApi.h"
#import "QMUsersService.h"
#import "SVProgressHud.h"
#import "QMChatReceiver.h"

NSString *const kQMFriendsListCellIdentifier = @"QMFriendListCell";
NSString *const kQMDontHaveAnyFriendsCellIdentifier = @"QMDontHaveAnyFriendsCell";

@interface QMFriendsListDataSource()

<QMFriendListCellDelegate>

@property (strong, nonatomic) NSArray *searchResult;
@property (strong, nonatomic) NSArray *friendList;
@property (weak, nonatomic) UITableView *tableView;
@property (weak, nonatomic) UISearchDisplayController *searchDisplayController;
@property (weak, nonatomic) UITableView *tView;

@end

@implementation QMFriendsListDataSource

@synthesize friendList = _friendList;

- (void)dealloc {
    NSLog(@"%@ - %@",  NSStringFromSelector(_cmd), self);
    [[QMChatReceiver instance] unsubscribeForTarget:self];
}

- (instancetype)initWithTableView:(UITableView *)tableView searchDisplayController:(UISearchDisplayController *)searchDisplayController {
    
    self = [super init];
    if (self) {
        
        self.tableView = tableView;
        self.tableView.dataSource = self;
        self.tView = self.tableView;
        self.searchResult = [NSArray array];
        
        self.searchDisplayController = searchDisplayController;
        __weak __typeof(self)weakSelf = self;
        
        [[QMChatReceiver instance] chatContactListWilChangeWithTarget:self block:^{
            [[QMApi instance] retrieveFriendsIfNeeded:^(BOOL updated) {
                [weakSelf reloadDatasource];
            }];
        }];
        
        [[QMChatReceiver instance] chatDidReceiveContactAddRequestWithTarget:self block:^(NSUInteger userID) {
            [[QMApi instance] confirmAddContactRequest:userID completion:^(BOOL success) {
            }];
        }];
    }
    
    return self;
}

- (void)setFriendList:(NSArray *)friendList {
    _friendList = [self sortUsersByFullname:friendList];
}

- (NSArray *)friendList {
    
    if (self.searchDisplayController.isActive && self.searchDisplayController.searchBar.text.length > 0) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.fullName CONTAINS[cd] %@", self.searchDisplayController.searchBar.text];
        NSArray *filtered = [_friendList filteredArrayUsingPredicate:predicate];
        
        return filtered;
    }
    return _friendList;
}

- (void)reloadDatasource {
    
    self.friendList = [QMApi instance].friends;
    [self.tableView reloadData];
}

- (NSArray *)sortUsersByFullname:(NSArray *)users {
    
    NSSortDescriptor *sorter = [[NSSortDescriptor alloc]
                                initWithKey:@"fullName"
                                ascending:YES
                                selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *sortedUsers = [users sortedArrayUsingDescriptors:@[sorter]];
    
    return sortedUsers;
}

- (void)globalSearch:(NSString *)searchText {
    
    if (searchText.length == 0) {
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    QBUUserPagedResultBlock userPagedBlock = ^(QBUUserPagedResult *pagedResult) {
        
        NSArray *users = [weakSelf sortUsersByFullname:pagedResult.users];
        //Remove current user from search result
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.ID != %d", [QMApi instance].currentUser.ID];
        weakSelf.searchResult = [users filteredArrayUsingPredicate:predicate];
        [weakSelf.tableView reloadData];
    };
    
    
    PagedRequest *request = [[PagedRequest alloc] init];
    request.page = 1;
    request.perPage = 100;
    
    [[QMApi instance].usersService retrieveUsersWithFullName:searchText pagedRequest:request completion:userPagedBlock];
    
}

#pragma mark - UITableViewDataSource

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    if (self.searchDisplayController.isActive) {
        
        NSArray *users = [self usersAtSections:section];
        
        if (section == 0) {
            return users.count > 0 ? NSLocalizedString(@"QM_STR_FRIENDS", nil) : nil;
        }
        else {
            return users.count > 0 ? NSLocalizedString(@"QM_STR_ALL_USERS", nil) : nil;
        }
    }
    else {
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return self.searchDisplayController.isActive ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    NSArray *users = [self usersAtSections:section];
    if (self.searchDisplayController.isActive) {
        return users.count;
    } else {
        return users.count > 0 ? users.count : 1;
    }
}

- (NSArray *)usersAtSections:(NSInteger)section {
    return (section == 0 ) ? self.friendList : self.searchResult;
}

- (QBUUser *)userAtIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *users = [self usersAtSections:indexPath.section];
    QBUUser *user = users[indexPath.row];
    
    return user;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *users = [self usersAtSections:indexPath.section];
    
    if (!self.searchDisplayController.isActive) {
        if (users.count == 0) {
            UITableViewCell *cell = [self.tView dequeueReusableCellWithIdentifier:kQMDontHaveAnyFriendsCellIdentifier];
            return cell;
        }
    }
    
    QMFriendListCell *cell = [self.tView dequeueReusableCellWithIdentifier:kQMFriendsListCellIdentifier];
    QBUUser *user = users[indexPath.row];
    
    cell.contactlistItem = [[QMApi instance] contactItemWithUserID:user.ID];
    cell.userData = user;
    cell.searchText = self.searchDisplayController.searchBar.text;
    cell.delegate = self;
    
    return cell;
}

#pragma mark - QMFriendListCellDelegate

- (void)friendListCell:(QMFriendListCell *)cell pressAddBtn:(UIButton *)sender {
    
    NSIndexPath *indexPath = [self.searchDisplayController.searchResultsTableView indexPathForCell:cell];
    NSArray *datasource = [self usersAtSections:indexPath.section];
    QBUUser *user = datasource[indexPath.row];
    
    [[QMApi instance] addUserToContactListRequest:user.ID completion:^(BOOL success) {
        
    }];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    
    [self globalSearch:searchString];
    
    return NO;
}

- (void) searchDisplayControllerWillBeginSearch:(UISearchDisplayController *)controller {
 
    self.tableView.dataSource = nil;
    self.tableView = controller.searchResultsTableView;
}

- (void) searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
    self.tableView = self.tView;
    self.tableView.dataSource = self;
    [self.tableView reloadData];
}

@end