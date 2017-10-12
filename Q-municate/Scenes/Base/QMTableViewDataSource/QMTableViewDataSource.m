//
//  QMTableViewDataSource.m
//  Q-municate
//
//  Created by Andrey Ivanov on 01.04.15.
//  Copyright (c) 2015 Quickblox. All rights reserved.
//

#import "QMTableViewDataSource.h"
#import "QMSearchDataProvider.h"

@implementation QMTableViewDataSource


- (id)objectAtIndexPath:(NSIndexPath *)__unused indexPath {
    
    return nil;
}

- (NSIndexPath *)indexPathForObject:(id)__unused object {
    
    return nil;
}

- (CGFloat)heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath {
    
    return 0.0f;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section {
    
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)__unused tableView cellForRowAtIndexPath:(NSIndexPath *)__unused indexPath {
    
    return nil;
}


@end
