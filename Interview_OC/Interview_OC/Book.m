//
//  Book.m
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import "Book.h"

@implementation Book

- (NSString *)description {
    return [NSString stringWithFormat:@"<Book: %p> bookName = %@, price = %ld", self, self.bookName, (long)self.price];
}

@end
