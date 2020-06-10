//
//  MCSHLSParser.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSParser.h"
#import "MCSError.h"

@interface NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern;
@end

@interface MCSHLSParser ()<NSLocking> {
    NSRecursiveLock *_lock;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, strong, nullable) NSURL *URL;
@property (nonatomic, weak, nullable) id<MCSHLSParserDelegate> delegate;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *tsFragments;
@end

@implementation MCSHLSParser
- (instancetype)initWithURL:(NSURL *)URL delegate:(id<MCSHLSParserDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _delegate = delegate;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (NSURL *)tsURLWithTsFilename:(NSString *)filename {
    [self lock];
    @try {
        return [NSURL URLWithString:_tsFragments[filename]];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        _isCalledPrepare = YES;
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{ @autoreleasepool {
            [self _parse];
        }});
    } @catch (__unused NSException *exception) {

    } @finally {
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        
        _isClosed = YES;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize isDone = _isDone;
- (BOOL)isDone {
    [self lock];
    @try {
        return _isDone;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize isClosed = _isClosed;
- (BOOL)isClosed {
    [self lock];
    @try {
        return _isClosed;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)_parse {
    if ( self.isClosed )
        return;
    
    NSString *url = _URL.absoluteString;
    NSString *_Nullable contents = nil;
    __block NSError *_Nullable error = nil;
    do {
        NSURL *URL = [NSURL URLWithString:url];
        contents = [NSString stringWithContentsOfURL:URL encoding:0 error:&error];
        if ( contents == nil )
            break;

        // 是否重定向
        url = [self _urlsWithPattern:@"(?:.*\\.m3u8[^\\s]*)" url:url source:contents].firstObject;
    } while ( url != nil );

    if ( error != nil || contents == nil ) {
        [self _onError:error ?: [NSError mcs_errorForHLSFileParseError:_URL]];
        return;
    }
 
    NSMutableString *indexFileContents = contents.mutableCopy;
    NSMutableDictionary<NSString *, NSString *> *tsFragments = NSMutableDictionary.dictionary;
    [[contents mcs_rangesByMatchingPattern:@"(?:.*\\.ts[^\\s]*)"] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSString *url = [self _urlWithMatchedString:matched];
        NSString *filename = [self.delegate parser:self tsFilenameForUrl:url];
        tsFragments[filename] = url;
        if ( filename != nil ) [indexFileContents replaceCharactersInRange:rangeValue withString:filename];
    }];
 
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[indexFileContents mcs_rangesByMatchingPattern:@"#EXT-X-KEY:METHOD=AES-128,URI=\".*\""] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSInteger URILocation = [matched rangeOfString:@"\""].location + 1;
        NSRange URIRange = NSMakeRange(URILocation, matched.length-URILocation-1);
        NSString *URI = [matched substringWithRange:URIRange];
        NSData *keyData = [NSData dataWithContentsOfURL:[NSURL URLWithString:URI] options:0 error:&error];
        if ( error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *filename = [self.delegate parser:self AESKeyFilenameForURI:URI];
        NSString *filepath = [self.delegate parser:self AESKeyWritePathForFilename:filename];
        [keyData writeToFile:filepath options:0 error:&error];
        if ( error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *reset = [matched stringByReplacingCharactersInRange:URIRange withString:filename];
        [indexFileContents replaceCharactersInRange:rangeValue withString:reset];
    }];

    if ( error != nil ) {
        [self _onError:error];
        return;
    }
    
    if ( ![tsFragments writeToFile:[self.delegate tsFragmentsWritePathForParser:self] atomically:YES] ) {
        [self _onError:[NSError mcs_errorForHLSFileParseError:_URL]];
        return;
    }
    
    if ( ![indexFileContents writeToFile:[self.delegate indexFileWritePathForParser:self] atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
        [self _onError:error];
        return;
    }
    
    [self lock];
    _tsFragments = tsFragments.copy;
    _isDone = YES;
    [self unlock];
    [self.delegate parserParseDidFinish:self];
}

- (nullable NSArray<NSString *> *)_urlsWithPattern:(NSString *)pattern url:(NSString *)url source:(NSString *)source {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[source mcs_rangesByMatchingPattern:pattern] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *matched = [source substringWithRange:[range rangeValue]];
        NSString *matchedUrl = [self _urlWithMatchedString:matched];
        [m addObject:matchedUrl];
    }];
    
    return m.count != 0 ? m.copy : nil;
}

- (NSString *)_urlWithMatchedString:(NSString *)matched {
    NSString *url = nil;
    if ( [matched containsString:@"://"] ) {
        url = matched;
    }
    else if ( [matched hasPrefix:@"/"] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", _URL.scheme, _URL.host, matched];
    }
    else {
        url = [NSString stringWithFormat:@"%@/%@", _URL.absoluteString.stringByDeletingLastPathComponent, matched];
    }
    return url;
}

- (void)_onError:(NSError *)error {
    if ( error.code != MCSHLSFileParseError ) {
#ifdef DEBUG
        NSLog(@"%@", error);
#endif
        error = [NSError mcs_errorForHLSFileParseError:_URL];
    }
    [self.delegate parser:self anErrorOccurred:error];
}

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end

@implementation NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    [regex enumerateMatchesInString:self options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if ( result != nil ) {
            [m addObject:[NSValue valueWithRange:result.range]];
        }
    }];
    return m.count != 0 ? m.copy : nil;
}
@end
