//
//  Author.m
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import "Author.h"

@implementation Author

- (NSString *)description {
    return [NSString stringWithFormat:@"<Author: %p> authorName = %@, age = %ld", self, self.authorName, (long)self.age];
}

@end
