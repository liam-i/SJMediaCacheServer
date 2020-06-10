//
//  MCSResource+MCSPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSVODResource.h"
#import "MCSResourcePartialContent.h"
#import "MCSResourceSubclass.h"
#import "MCSResourceDefines.h"

// 私有方法, 请勿使用

NS_ASSUME_NONNULL_BEGIN
@interface MCSVODResource (MCSPrivate)<MCSReadWrite>
@property (nonatomic) NSInteger id;
@property (nonatomic, strong, readonly) NSMutableArray<MCSResourcePartialContent *> *contents;
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (void)addContents:(nullable NSArray<MCSResourcePartialContent *> *)contents;
- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content;
- (MCSResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;

@property (nonatomic) NSInteger numberOfCumulativeUsage; ///< 累计被使用次数
@property (nonatomic) NSTimeInterval updatedTime;        ///< 最后一次更新时的时间
@property (nonatomic) NSTimeInterval createdTime;        ///< 创建时间
@end
NS_ASSUME_NONNULL_END