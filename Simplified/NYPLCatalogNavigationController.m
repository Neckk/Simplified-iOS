#import "NYPLCatalogFeedViewController.h"
#import "NYPLConfiguration.h"

#import "NYPLCatalogNavigationController.h"

@implementation NYPLCatalogNavigationController

#pragma mark NSObject

- (instancetype)init
{
  NYPLCatalogFeedViewController *const viewController =
    [[NYPLCatalogFeedViewController alloc]
     initWithURL:[NYPLConfiguration mainFeedURL]];
  
  viewController.title = NSLocalizedString(@"Catalog", nil);
  
  self = [super initWithRootViewController:viewController];
  if(!self) return nil;
  
  self.tabBarItem.image = [UIImage imageNamed:@"Catalog"];
  
  // The top-level view controller uses the same image used for the tab bar in place of the usual
  // title text.
  viewController.navigationItem.titleView =
    [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Catalog"]];
  
  return self;
}

@end
