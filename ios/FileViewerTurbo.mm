#import "FileViewerTurbo.h"

#import <QuickLook/QuickLook.h>

#import <RNFileViewerTurboSpec/RNFileViewerTurboSpec.h>

@interface File: NSObject<QLPreviewItem>

@property(readonly, nullable, nonatomic) NSURL *previewItemURL;
@property(readonly, nullable, nonatomic) NSString *previewItemTitle;

- (id)initWithPath:(NSString *)file title:(NSString *)title;

@end

@interface FileViewerTurbo ()<QLPreviewControllerDelegate>
@end

@implementation File

- (id)initWithPath:(NSString *)file title:(NSString *)title {
    if(self = [super init]) {
        _previewItemURL = [NSURL fileURLWithPath:file];
        _previewItemTitle = title;
    }
    return self;
}

@end

@interface CustomQLViewController: QLPreviewController<QLPreviewControllerDataSource>

@property(nonatomic, strong) File *file;
@property(nonatomic, strong) NSNumber *invocation;

- (void)dismissView:(id)sender;

@end

@implementation CustomQLViewController

- (instancetype)initWithFile:(File *)file identifier:(NSNumber *)invocation {
    if(self = [super init]) {
        _file = file;
        _invocation = invocation;
        self.dataSource = self;
    }
    return self;
}

// The Done button's target used to be `FileViewerTurbo` itself (a shared
// module instance, not per-presentation) — its `dismissView:` re-derived
// "whatever's topmost right now" via `+topViewController`'s heuristic
// subview/responder walk at TAP time, instead of dismissing the specific
// controller this invocation actually presented. That's fragile for
// anything whose own content embeds a nested child view controller
// QuickLook doesn't expose through the normal `presentedViewController`
// chain — confirmed on device with a CSV (QuickLook's spreadsheet
// renderer): the button animated but dismissed nothing, because
// `topViewController` resolved to the wrong controller by then. `self`
// here IS the exact presented controller, known at present-time —
// dismissing through it can't drift the way a fresh top-of-hierarchy guess
// can (`dismissViewControllerAnimated:` on anything in the presented chain
// forwards to the actual presenter regardless).
- (void)dismissView:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)prefersStatusBarHidden {
    UIWindowScene *windowScene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject;
    return windowScene.statusBarManager.isStatusBarHidden;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller{
    return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index{
    return self.file;
}

@end

@implementation FileViewerTurbo

static NSNumber *invocationId = @33341;

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (UIWindow*)keyWindow {
    for (UIWindowScene *windowScene in UIApplication.sharedApplication.connectedScenes) {
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    return nil;
}

+ (UIViewController*)topViewController {
    UIWindow *keyWindow = [self keyWindow];
    UIViewController *presenterViewController = [self topViewControllerWithRootViewController:keyWindow.rootViewController];
    return presenterViewController ? presenterViewController : keyWindow.rootViewController;
}

+ (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)viewController {
    if ([viewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*)viewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    }
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navContObj = (UINavigationController*)viewController;
        return [self topViewControllerWithRootViewController:navContObj.visibleViewController];
    }
    if (viewController.presentedViewController && !viewController.presentedViewController.isBeingDismissed) {
        UIViewController* presentedViewController = viewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    for (UIView *view in [viewController.view subviews]) {
        id subViewController = [view nextResponder];
        if ( subViewController && [subViewController isKindOfClass:[UIViewController class]]) {
            if ([(UIViewController *)subViewController presentedViewController]  && ![subViewController presentedViewController].isBeingDismissed) {
                return [self topViewControllerWithRootViewController:[(UIViewController *)subViewController presentedViewController]];
            }
        }
    }
    return viewController;
}

- (void)previewControllerDidDismiss:(CustomQLViewController *)controller {
    [self emitOnViewerDidDismiss];
}

RCT_EXPORT_MODULE(FileViewerTurbo)

RCT_EXPORT_METHOD(open:(NSString *)path
                  options:(JS::NativeFileViewerTurbo::Options &)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject) {

      UIBarButtonItem *buttonItem;
      NSString *displayName = options.displayName();
      NSString *doneButtonTitle = options.doneButtonTitle();
      NSString *doneButtonPosition = options.doneButtonPosition();
      NSString *modalPresentationStyle = options.modalPresentationStyle();
      BOOL disableInteractiveDismissal = options.disableInteractiveDismissal().value_or(false);

      File *file = [[File alloc] initWithPath:path title:displayName];

      QLPreviewController *controller = [[CustomQLViewController alloc] initWithFile:file identifier:invocationId];
      controller.delegate = self;

      UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];

      // `.automatic` isn't reliably `.pageSheet` in every app's own
      // presenting view-controller context — some setups resolve it to
      // `.fullScreen` instead, silently losing the swipeable card look and
      // the dimmed peek of the app behind it. Set explicitly rather than
      // depending on that resolution; `pageSheet` (the default here) is
      // what most apps actually want QuickLook to look like.
      if ([modalPresentationStyle isEqualToString:@"fullScreen"]) {
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
      } else if ([modalPresentationStyle isEqualToString:@"formSheet"]) {
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
      } else if ([modalPresentationStyle isEqualToString:@"automatic"]) {
        navigationController.modalPresentationStyle = UIModalPresentationAutomatic;
      } else {
        navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
      }

      if (@available(iOS 13.0, *)) {
          if (disableInteractiveDismissal) {
            [controller setModalInPresentation: true];
            [navigationController setModalInPresentation: true];
          }
      }

      // Targets `controller` (this specific presentation), not `self` — see
      // `CustomQLViewController.dismissView:`'s own doc comment for why.
      if (doneButtonTitle) {
        buttonItem = [[UIBarButtonItem alloc] initWithTitle:doneButtonTitle style:UIBarButtonItemStylePlain target:controller action:@selector(dismissView:)];
      } else {
        buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:controller action:@selector(dismissView:)];
      }

      if ([doneButtonPosition isEqualToString: @"left"]) {
        controller.navigationItem.leftBarButtonItem = buttonItem;
      } else if ([doneButtonPosition isEqualToString: @"right"]) {
        controller.navigationItem.rightBarButtonItem = buttonItem;
      } else {
        controller.navigationItem.leftBarButtonItem = buttonItem;
      }

      if ([QLPreviewController canPreviewItem:file]) {
        [[FileViewerTurbo topViewController] presentViewController:navigationController animated:YES completion:^{
          resolve(nil);
        }];
      } else {
        reject(@"FileViewerTurbo:open", @"File not supported", nil);
      }
};

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeFileViewerTurboSpecJSI>(params);
}

@end
