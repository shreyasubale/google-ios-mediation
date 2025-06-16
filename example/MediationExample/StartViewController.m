//
// Copyright (C) 2017 Google, Inc.
//
// StartViewController.m
// Mediation Example
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "StartViewController.h"
#import "ViewController.h"

typedef enum : NSUInteger {
  CellIndexObjC = 0,
  CellIndexSwift,
  CellIndexMRAID,
} CellIndex;

@interface StartViewController ()

@end

@implementation StartViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"Mediation Examples";
  
  // Update the second cell to show MRAID instead of Swift
  dispatch_async(dispatch_get_main_queue(), ^{
    NSIndexPath *swiftCellPath = [NSIndexPath indexPathForRow:1 inSection:0];
    UITableViewCell *swiftCell = [self.tableView cellForRowAtIndexPath:swiftCellPath];
    if (swiftCell) {
      swiftCell.textLabel.text = @"MRAID Custom Event";
    }
  });
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  switch (indexPath.row) {
    case CellIndexObjC:
      [self launchViewControllerOfType:AdSourceTypeCustomEventObjC];
      break;
    case CellIndexSwift:
      // Use Swift case for MRAID testing
      [self launchViewControllerOfType:AdSourceTypeMRAIDCustomEvent];
      break;
    default:
      break;
  }
}

- (void)launchViewControllerOfType:(AdSourceType)adSourceType {
  AdSourceConfig *config = [AdSourceConfig configWithType:adSourceType];
  ViewController *controller = [ViewController controllerWithAdSourceConfig:config];
  [self.navigationController pushViewController:controller animated:YES];
}

@end
