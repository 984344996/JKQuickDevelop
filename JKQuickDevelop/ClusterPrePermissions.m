//
//  ClusterPrePermissions.m
//  ClusterPrePermissions
//
//  Created by Rizwan Sattar on 4/7/14.
//  Copyright (c) 2014 Cluster Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

typedef NS_ENUM(NSInteger, ClusterTitleType) {
    ClusterTitleTypeRequest,
    ClusterTitleTypeDeny
};


#import "ClusterPrePermissions.h"
#import "AppDelegate.h"

#import <AddressBook/AddressBook.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <EventKit/EventKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
//at least iOS 9 code here
#import <Photos/PHAsset.h>
@import Contacts;
#endif

NSString *const ClusterPrePermissionsDidAskForPushNotifications = @"ClusterPrePermissionsDidAskForPushNotifications";

@interface ClusterPrePermissions () <UIAlertViewDelegate, CLLocationManagerDelegate>

#pragma mark - Event handers
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler avPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler photoPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler contactPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler eventPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler locationPermissionCompletionHandler;
@property (copy, nonatomic) ClusterPrePermissionCompletionHandler pushNotificationPermissionCompletionHandler;

#pragma mark - Vars
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (assign, nonatomic) ClusterLocationAuthorizationType locationAuthorizationType;
@property (assign, nonatomic) ClusterPushNotificationType requestedPushNotificationTypes;

@end

static ClusterPrePermissions *__sharedInstance;

@implementation ClusterPrePermissions

#pragma mark - Retrieve permission
- (void)retrievePermission:(NSString *)requestTitle message:(NSString *)message denyButtonTitle:(NSString *)denyButtonTitle grantButtonTitle:(NSString *)grantButtonTitle{
    UIAlertController *alertContorler                = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *actionCancel                      = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleCancel handler:nil];
    
    UIAlertAction *actionGrant                       = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
#ifdef __IPHONE_8_0
        //跳入当前App设置界面
        [[UIApplication sharedApplication]openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
#else
        //适配iOS7 ,跳入系统设置界面
        [[UIApplication sharedApplication]openURL:[NSURL URLWithString:@"prefs:General&path=Reset"]];
#endif
    }];
    
    [alertContorler addAction:actionCancel];
    [alertContorler addAction:actionGrant];
    [self showAlertController:alertContorler];
}

#pragma mark - Get authorization status
+ (instancetype) sharedPermissions
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[ClusterPrePermissions alloc] init];
    });
    return __sharedInstance;
}

+ (ClusterAuthorizationStatus) AVPermissionAuthorizationStatusForMediaType:(NSString*)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case AVAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case AVAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) cameraPermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeVideo];
}

+ (ClusterAuthorizationStatus) microphonePermissionAuthorizationStatus
{
    return [ClusterPrePermissions AVPermissionAuthorizationStatusForMediaType:AVMediaTypeAudio];
}

+ (ClusterAuthorizationStatus) photoPermissionAuthorizationStatus
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    switch (status) {
        case PHAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;
        
        case PHAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;
        
        case PHAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;
        
        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
#else
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    switch (status) {
        case ALAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;
            
        case ALAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;
            
        case ALAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;
            
        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
#endif
}


+ (ClusterAuthorizationStatus) contactsPermissionAuthorizationStatus
{
    ClusterContactsAuthorizationType authType;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    authType = (ClusterContactsAuthorizationType)status;
#else
    //lower than iOS 9 code here
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    authType = (ClusterContactsAuthorizationType)status;
#endif
    switch (authType) {
        case ClusterContactsAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;
            
        case ClusterContactsAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;
            
        case ClusterContactsAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;
            
        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}


+ (ClusterAuthorizationStatus) eventPermissionAuthorizationStatus:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:
                  [[ClusterPrePermissions sharedPermissions] EKEquivalentEventType:eventType]];
    switch (status) {
        case EKAuthorizationStatusAuthorized:
            return ClusterAuthorizationStatusAuthorized;

        case EKAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case EKAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) locationPermissionAuthorizationStatus
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return ClusterAuthorizationStatusAuthorized;

        case kCLAuthorizationStatusDenied:
            return ClusterAuthorizationStatusDenied;

        case kCLAuthorizationStatusRestricted:
            return ClusterAuthorizationStatusRestricted;

        default:
            return ClusterAuthorizationStatusUnDetermined;
    }
}

+ (ClusterAuthorizationStatus) pushNotificationPermissionAuthorizationStatus
{
    BOOL didAskForPermission = [[NSUserDefaults standardUserDefaults] boolForKey:ClusterPrePermissionsDidAskForPushNotifications];
    
    if (didAskForPermission) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
            // iOS8+
            if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]) {
                return ClusterAuthorizationStatusAuthorized;
            } else {
                return ClusterAuthorizationStatusDenied;
            }
        } else {
            // Add compiler check to avoid warnings, if deployment target >= 8.0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
            // iOS 7
            if ([[UIApplication sharedApplication] enabledRemoteNotificationTypes] == UIRemoteNotificationTypeNone) {
                return ClusterAuthorizationStatusDenied;
            } else {
                return ClusterAuthorizationStatusAuthorized;
            }
#else
            // Impossible state to be in: iOS 8 device, but somehow doesn't respond to isRegisteredForRemoteNotifications?
            return ClusterAuthorizationStatusDenied;
#endif
        }
    } else {
        return ClusterAuthorizationStatusUnDetermined;
    }
}

#pragma mark - Push Notification Permissions Help

- (void) showPushNotificationPermissionsWithType:(ClusterPushNotificationType)requestedType
                                           title:(NSString *)requestTitle
                                         message:(NSString *)message
                                 denyButtonTitle:(NSString *)denyButtonTitle
                                grantButtonTitle:(NSString *)grantButtonTitle
                               completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Enable Push Notifications?";
    }
    denyButtonTitle = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (status == ClusterAuthorizationStatusUnDetermined) {
        self.pushNotificationPermissionCompletionHandler = completionHandler;
        self.requestedPushNotificationTypes              = requestedType;
        
        UIAlertController *alertContorler                = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *actionCancel                      = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self firePushNotificationPermissionCompletionHandler];
        }];
        
        UIAlertAction *actionGrant                       = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showActualPushNotificationPermissionAlert];
        }];
        
        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
        
    } else {
        if (completionHandler) {
            completionHandler((status == ClusterAuthorizationStatusUnDetermined),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}

- (void) showActualPushNotificationPermissionAlert
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        // iOS8+
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)self.requestedPushNotificationTypes
                                                                                categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    } else {
        // Add compiler check to avoid warnings, if deployment target >= 8.0
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationType)self.requestedPushNotificationTypes];
#endif
    }
    [[NSUserDefaults standardUserDefaults] setBool:YES
                                            forKey:ClusterPrePermissionsDidAskForPushNotifications];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidBecomeActive
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [self firePushNotificationPermissionCompletionHandler];
}


- (void) firePushNotificationPermissionCompletionHandler
{
    ClusterAuthorizationStatus status = [ClusterPrePermissions pushNotificationPermissionAuthorizationStatus];
    if (self.pushNotificationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
            
        } else if (status == ClusterAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
            
        } else if (status == ClusterAuthorizationStatusUnDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        }
        self.pushNotificationPermissionCompletionHandler((status == ClusterAuthorizationStatusAuthorized),
                                                         userDialogResult,
                                                         systemDialogResult);
        self.pushNotificationPermissionCompletionHandler = nil;
    }
}


#pragma mark - AV Permissions Help

- (void) showAVPermissionsWithType:(ClusterAVAuthorizationType)mediaType
                             title:(NSString *)requestTitle
                           message:(NSString *)message
                   denyButtonTitle:(NSString *)denyButtonTitle
                  grantButtonTitle:(NSString *)grantButtonTitle
                 completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (mediaType) {
            case ClusterAVAuthorizationTypeCamera:
                requestTitle = @"Access Camera?";
                break;

            default:
                requestTitle = @"Access Microphone?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (status == AVAuthorizationStatusNotDetermined) {
        self.avPermissionCompletionHandler = completionHandler;
        
        UIAlertController *alertContorler = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self fireAVPermissionCompletionHandlerWithType:mediaType];
        }];
        
        UIAlertAction *actionGrant = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showActualAVPermissionAlertWithType:mediaType];
        }];
        
        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
        
    } else {
        if (completionHandler) {
            completionHandler((status == AVAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showCameraPermissionsWithTitle:(NSString *)requestTitle
                                message:(NSString *)message
                        denyButtonTitle:(NSString *)denyButtonTitle
                       grantButtonTitle:(NSString *)grantButtonTitle
                      completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showAVPermissionsWithType:ClusterAVAuthorizationTypeCamera
                              title:requestTitle
                            message:message
                    denyButtonTitle:denyButtonTitle
                   grantButtonTitle:grantButtonTitle
                  completionHandler:completionHandler];
}


- (void) showMicrophonePermissionsWithTitle:(NSString *)requestTitle
                                    message:(NSString *)message
                            denyButtonTitle:(NSString *)denyButtonTitle
                           grantButtonTitle:(NSString *)grantButtonTitle
                          completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showAVPermissionsWithType:ClusterAVAuthorizationTypeMicrophone
                              title:requestTitle
                            message:message
                    denyButtonTitle:denyButtonTitle
                   grantButtonTitle:grantButtonTitle
                  completionHandler:completionHandler];
}


- (void) showActualAVPermissionAlertWithType:(ClusterAVAuthorizationType)mediaType
{
    [AVCaptureDevice requestAccessForMediaType:[self AVEquivalentMediaType:mediaType]
                             completionHandler:^(BOOL granted) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     [self fireAVPermissionCompletionHandlerWithType:mediaType];
                                 });
                             }];
}


- (void) fireAVPermissionCompletionHandlerWithType:(ClusterAVAuthorizationType)mediaType
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:[self AVEquivalentMediaType:mediaType]];
    if (self.avPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == AVAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
            
        } else if (status == AVAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
            
        } else if (status == AVAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
            
        } else if (status == AVAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.avPermissionCompletionHandler((status == AVAuthorizationStatusAuthorized),
                                           userDialogResult,
                                           systemDialogResult);
        self.avPermissionCompletionHandler = nil;
    }
}


- (NSString*)AVEquivalentMediaType:(ClusterAVAuthorizationType)mediaType
{
    if (mediaType == ClusterAVAuthorizationTypeCamera) {
        return AVMediaTypeVideo;
    }
    else {
        return AVMediaTypeAudio;
    }
}

#pragma mark - Photo Permissions Help

- (void) showPhotoPermissionsWithTitle:(NSString *)requestTitle
                               message:(NSString *)message
                       denyButtonTitle:(NSString *)denyButtonTitle
                      grantButtonTitle:(NSString *)grantButtonTitle
                     completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Photos?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    ClusterAuthorizationStatus status = [ClusterPrePermissions photoPermissionAuthorizationStatus];
    if (status == ClusterAuthorizationStatusUnDetermined) {
        self.photoPermissionCompletionHandler = completionHandler;

        UIAlertController *alertContorler     = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *actionCancel           = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self firePhotoPermissionCompletionHandler];
        }];

        UIAlertAction *actionGrant            = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showActualPhotoPermissionAlert];
        }];

        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
        
    } else {
        if (completionHandler) {
            completionHandler((status == ClusterAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualPhotoPermissionAlert
{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        [self firePhotoPermissionCompletionHandler];
    }];
#else
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        [self firePhotoPermissionCompletionHandler];
        *stop = YES;
    } failureBlock:^(NSError *error) {
        [self firePhotoPermissionCompletionHandler];
    }];
#endif
}


- (void) firePhotoPermissionCompletionHandler
{
    ClusterAuthorizationStatus status = [ClusterPrePermissions photoPermissionAuthorizationStatus];
    if (self.photoPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterAuthorizationStatusUnDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
            
        } else if (status == ClusterAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
            
        } else if (status == ClusterAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
            
        } else if (status == ClusterAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        
        self.photoPermissionCompletionHandler((status == ClusterAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.photoPermissionCompletionHandler = nil;
    }
}


#pragma mark - Contact Permissions Help
/*!
* @discussion get the authorization status of accessing contacts. It handles both uses of Contacts framework iOS 9+ or AddressBook fremwork < iOS 9
*/
-(ClusterContactsAuthorizationType)getContactsAuthorizationType{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    return (ClusterContactsAuthorizationType)status;
#else
    //lower than iOS 9 code here
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    return (ClusterContactsAuthorizationType)status;
#endif
}

- (void) showContactsPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Contacts?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    ClusterContactsAuthorizationType status = [self getContactsAuthorizationType];
    
    
    if (status == ClusterContactsAuthorizationStatusNotDetermined) {
        self.contactPermissionCompletionHandler = completionHandler;
        UIAlertController *alertContorler = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // User said NO, that jerk.
            [self fireContactPermissionCompletionHandler];
        }];
        
        UIAlertAction *actionGrant = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // User granted access, now try to trigger the real contacts access
            [self showActualContactPermissionAlert];
        }];
        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
        
    } else {
        if (completionHandler) {
            completionHandler(status == ClusterContactsAuthorizationStatusAuthorized,
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualContactPermissionAlert
{
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_9_0
    //at least iOS 9 code here
    CNContactStore *contactsStore = [[CNContactStore alloc] init];
    [contactsStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    }];
#else
    //lower than iOS 9 code here
    CFErrorRef error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(nil, &error);
    ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireContactPermissionCompletionHandler];
        });
    });
#endif
    
}


- (void) fireContactPermissionCompletionHandler
{
    ClusterContactsAuthorizationType status = [self getContactsAuthorizationType];
    if (self.contactPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == ClusterContactsAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == ClusterContactsAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == ClusterContactsAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == ClusterContactsAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.contactPermissionCompletionHandler((status == ClusterContactsAuthorizationStatusAuthorized),
                                                userDialogResult,
                                                systemDialogResult);
        self.contactPermissionCompletionHandler = nil;
    }
}


#pragma mark - Event Permissions Help


- (void) showEventPermissionsWithType:(ClusterEventAuthorizationType)eventType
                                Title:(NSString *)requestTitle
                              message:(NSString *)message
                      denyButtonTitle:(NSString *)denyButtonTitle
                     grantButtonTitle:(NSString *)grantButtonTitle
                    completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        switch (eventType) {
            case ClusterEventAuthorizationTypeEvent:
                requestTitle = @"Access Calendar?";
                break;

            default:
                requestTitle = @"Access Reminders?";
                break;
        }
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];

    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (status == EKAuthorizationStatusNotDetermined) {
        self.eventPermissionCompletionHandler = completionHandler;
        UIAlertController *alertContorler = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            /// User said NO, that jerk.
            [self fireEventPermissionCompletionHandler:eventType];
        }];
        
        UIAlertAction *actionGrant = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // User granted access, now try to trigger the real contacts access
            [self showActualEventPermissionAlert:eventType];
        }];
        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
    } else {
        if (completionHandler) {
            completionHandler((status == EKAuthorizationStatusAuthorized),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualEventPermissionAlert:(ClusterEventAuthorizationType)eventType
{
    EKEventStore *aStore = [[EKEventStore alloc] init];
    [aStore requestAccessToEntityType:[self EKEquivalentEventType:eventType] completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fireEventPermissionCompletionHandler:eventType];
        });
    }];
}


- (void) fireEventPermissionCompletionHandler:(ClusterEventAuthorizationType)eventType
{
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:[self EKEquivalentEventType:eventType]];
    if (self.eventPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == EKAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
        } else if (status == EKAuthorizationStatusAuthorized) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
        } else if (status == EKAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
        } else if (status == EKAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.eventPermissionCompletionHandler((status == EKAuthorizationStatusAuthorized),
                                              userDialogResult,
                                              systemDialogResult);
        self.eventPermissionCompletionHandler = nil;
    }
}

- (NSUInteger)EKEquivalentEventType:(ClusterEventAuthorizationType)eventType {
    if (eventType == ClusterEventAuthorizationTypeEvent) {
        return EKEntityTypeEvent;
    }
    else {
        return EKEntityTypeReminder;
    }
}

#pragma mark - Location Permission Help

- (void) showLocationPermissionsWithTitle:(NSString *)requestTitle
                                  message:(NSString *)message
                          denyButtonTitle:(NSString *)denyButtonTitle
                         grantButtonTitle:(NSString *)grantButtonTitle
                        completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    [self showLocationPermissionsForAuthorizationType:ClusterLocationAuthorizationTypeAlways
                                                title:requestTitle
                                              message:message
                                      denyButtonTitle:denyButtonTitle
                                     grantButtonTitle:grantButtonTitle
                                    completionHandler:completionHandler];
}

- (void) showLocationPermissionsForAuthorizationType:(ClusterLocationAuthorizationType)authorizationType
                                               title:(NSString *)requestTitle
                                             message:(NSString *)message
                                     denyButtonTitle:(NSString *)denyButtonTitle
                                    grantButtonTitle:(NSString *)grantButtonTitle
                                   completionHandler:(ClusterPrePermissionCompletionHandler)completionHandler
{
    if (requestTitle.length == 0) {
        requestTitle = @"Access Location?";
    }
    denyButtonTitle  = [self titleFor:ClusterTitleTypeDeny fromTitle:denyButtonTitle];
    grantButtonTitle = [self titleFor:ClusterTitleTypeRequest fromTitle:grantButtonTitle];
    
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined) {
        self.locationPermissionCompletionHandler = completionHandler;
        self.locationAuthorizationType = authorizationType;
        
        UIAlertController *alertContorler = [UIAlertController alertControllerWithTitle:requestTitle message:message preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *actionCancel       = [UIAlertAction actionWithTitle:denyButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self fireLocationPermissionCompletionHandler];
        }];

        UIAlertAction *actionGrant        = [UIAlertAction actionWithTitle:grantButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self showActualLocationPermissionAlert];
        }];
        [alertContorler addAction:actionCancel];
        [alertContorler addAction:actionGrant];
        [self showAlertController:alertContorler];
        
    } else {
        if (completionHandler) {
            completionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                              ClusterDialogResultNoActionTaken,
                              ClusterDialogResultNoActionTaken);
        }
    }
}


- (void) showActualLocationPermissionAlert
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeAlways &&
        [self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
        
    } else if (self.locationAuthorizationType == ClusterLocationAuthorizationTypeWhenInUse &&
               [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {

        [self.locationManager requestWhenInUseAuthorization];
    }
    
    [self.locationManager startUpdatingLocation];
}


- (void) fireLocationPermissionCompletionHandler
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (self.locationPermissionCompletionHandler) {
        ClusterDialogResult userDialogResult = ClusterDialogResultGranted;
        ClusterDialogResult systemDialogResult = ClusterDialogResultGranted;
        if (status == kCLAuthorizationStatusNotDetermined) {
            userDialogResult = ClusterDialogResultDenied;
            systemDialogResult = ClusterDialogResultNoActionTaken;
            
        } else if ([self locationAuthorizationStatusPermitsAccess:status]) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultGranted;
            
        } else if (status == kCLAuthorizationStatusDenied) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultDenied;
            
        } else if (status == kCLAuthorizationStatusRestricted) {
            userDialogResult = ClusterDialogResultGranted;
            systemDialogResult = ClusterDialogResultParentallyRestricted;
        }
        self.locationPermissionCompletionHandler(([self locationAuthorizationStatusPermitsAccess:status]),
                                                 userDialogResult,
                                                 systemDialogResult);
        self.locationPermissionCompletionHandler = nil;
    }
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation], self.locationManager = nil;
    }
}

- (BOOL)locationAuthorizationStatusPermitsAccess:(CLAuthorizationStatus)authorizationStatus
{
    return authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
    authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse;
}

#pragma mark CLLocationManagerDelegate

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined) {
        [self fireLocationPermissionCompletionHandler];
    }
}

#pragma mark - Titles

- (NSString *)titleFor:(ClusterTitleType)titleType fromTitle:(NSString *)title
{
    switch (titleType) {
        case ClusterTitleTypeDeny:
            title = (title.length == 0) ? @"Not Now" : title;
            break;
        case ClusterTitleTypeRequest:
            title = (title.length == 0) ? @"Give Access" : title;
            break;
        default:
            title = @"";
            break;
    }
    return title;
}

- (void) showAlertController:(UIAlertController *)controller{
    [[[[AppDelegate sharedAppDelegate] window] rootViewController] presentViewController:controller animated:YES completion:nil];
}

@end
