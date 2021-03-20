//
//  MCSAssetExporterManager.h
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import <Foundation/Foundation.h>
#import "MCSInterfaces.h"
#import "MCSAssetExporterDefines.h"
 
NS_ASSUME_NONNULL_BEGIN
@interface MCSAssetExporterManager : NSObject<MCSAssetExporterManager>
+ (instancetype)shared;

- (void)registerObserver:(id<MCSAssetExportObserver>)observer;
- (void)removeObserver:(id<MCSAssetExportObserver>)observer;

@property (nonatomic) NSInteger maxConcurrentExportCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<MCSAssetExporter>> *allExporters;
 
- (id<MCSAssetExporter>)exportAssetWithURL:(NSURL *)URL;
- (void)removeAssetWithURL:(NSURL *)URL;
- (void)removeAllAssets;
 
- (MCSAssetExportStatus)statusWithURL:(NSURL *)URL;
- (float)progressWithURL:(NSURL *)URL;
- (nullable NSURL *)playbackURLForExportedAssetWithURL:(NSURL *)URL;
 
- (void)synchronizeForAssetWithURL:(NSURL *)URL;
- (void)synchronize;
@end
NS_ASSUME_NONNULL_END