//
//  main.m
//  CodeInjectorMaster
//
//  Created by Maxim Makhun on 5/13/17.
//  Copyright © 2017 Maxim Makhun. All rights reserved.
//

@import Foundation;

#import "CodeInjectorMaster.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        CodeInjectorMaster *master = [CodeInjectorMaster new];
        [master inject];
    }
    
    return 0;
}
