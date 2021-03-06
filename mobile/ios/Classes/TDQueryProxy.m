//
//  TDQueryProxy.m
//  titouchdb
//
//  Created by Paul Mietz Egli on 12/10/12.
//
//

#import "TDQueryProxy.h"
#import "TiProxy+Errors.h"
#import "TDDatabaseProxy.h"
#import "TDDocumentProxy.h"
#import "TDRevisionProxy.h"

@interface TDQueryProxy ()
@property (nonatomic, assign) TDDatabaseProxy * database;
@property (nonatomic, strong) CBLQuery * query;
@property (nonatomic, strong) NSError * lastError;
@end

@interface TDQueryEnumeratorProxy : TiProxy
@property (nonatomic, assign) TDQueryProxy * query;
@property (nonatomic, strong) CBLQueryEnumerator * enumerator;
+ (instancetype)proxyWithQuery:(TDQueryProxy *)query queryEnumerator:(CBLQueryEnumerator *)queryEnumerator;
@end

@interface TDQueryRowProxy : TiProxy
@property (nonatomic, assign) TDQueryEnumeratorProxy * queryEnumerator;
@property (nonatomic, strong) CBLQueryRow * row;
+ (instancetype)proxyWithQueryEnumerator:(TDQueryEnumeratorProxy *)enumerator queryRow:(CBLQueryRow *)row;
@end


@implementation TDQueryProxy

+ (instancetype)proxyWithDatabase:(TDDatabaseProxy *)database query:(CBLQuery *)query {
    TDQueryProxy * result = [[[TDQueryProxy alloc] initWithExecutionContext:database.pageContext CBLQuery:query] autorelease];
    result.database = database;
    return result;
}

- (id)initWithExecutionContext:(id<TiEvaluator>)context CBLQuery:(CBLQuery *)query {
    if (self = [super _initWithPageContext:context]) {
        self.query = query;
    }
    return self;
}

- (void)dealloc {
    self.query = nil;
    [super dealloc];
}

#pragma mark Properties

- (id)limit {
    return NUMLONG(self.query.limit);
}

- (void)setLimit:(id)value {
    self.query.limit = [value unsignedIntegerValue];
}

- (id)skip {
    return NUMLONG(self.query.skip);
}

- (void)setSkip:(id)value {
    self.query.skip = [value unsignedIntegerValue];
}

- (id)descending {
    return NUMBOOL(self.query.descending);
}

- (void)setDescending:(id)value {
    self.query.descending = [value boolValue];
}

- (id)startKey {
    return self.query.startKey;
}

- (void)setStartKey:(id)value {
    self.query.startKey = value;
}

- (id)endKey {
    return self.query.endKey;
}

- (void)setEndKey:(id)value {
    self.query.endKey = value;
}

- (id)startKeyDocID {
    return self.query.startKeyDocID;
}

- (void)setStartKeyDocID:(id)value {
    self.query.startKeyDocID = value;
}

- (id)endKeyDocID {
    return self.query.endKeyDocID;
}

- (void)setEndKeyDocID:(id)value {
    self.query.endKeyDocID = value;
}

- (id)indexUpdateMode {
    return NUMINT(self.query.indexUpdateMode);
}

- (void)setIndexUpdateMode:(id)value {
    self.query.indexUpdateMode = [value intValue];
}

- (id)keys {
    return self.query.keys ? self.query.keys : @[];
}

- (void)setKeys:(id)value {
    self.query.keys = value;
}

- (id)mapOnly {
    return NUMBOOL(self.query.mapOnly);
}

- (void)setMapOnly:(id)value {
    self.query.mapOnly = [value boolValue];
}

- (id)groupLevel {
    return NUMLONG(self.query.groupLevel);
}

- (void)setGroupLevel:(id)value {
    self.query.groupLevel = [value unsignedIntegerValue];
}

- (id)prefetch {
    return NUMBOOL(self.query.prefetch);
}

- (void)setPrefetch:(id)value {
    self.query.prefetch = [value boolValue];
}

- (id)allDocsMode {
    return NUMINT(self.query.allDocsMode);
}

- (void)setAllDocsMode:(id)value {
    self.query.allDocsMode = [value intValue];
}

- (id)error {
    return [self errorDict:self.lastError];
}

#pragma mark Public API

- (id)run:(id)args {
    NSError * error = nil;
    CBLQueryEnumerator * e = [self.query run:&error];
    self.lastError = error;
    
    if (error) {
        NSLog(@"run error: %@", error);
    }
    
    return e ? [TDQueryEnumeratorProxy proxyWithQuery:self queryEnumerator:e] : nil;
}

@end


@implementation TDQueryEnumeratorProxy

+ (instancetype)proxyWithQuery:(TDQueryProxy *)query queryEnumerator:(CBLQueryEnumerator *)queryEnumerator {
    return [[[TDQueryEnumeratorProxy alloc] initWithQuery:query queryEnumerator:queryEnumerator] autorelease];
}

- (id)initWithQuery:(TDQueryProxy *) query queryEnumerator:(CBLQueryEnumerator *)e {
    if (self = [super init]) {
        self.query = query;
        self.enumerator = e;
        
        // This is probably very inefficient, but without it, the
        // reset method won't work. Better to be inefficient than to
        // break compatibility.
        [self.enumerator allObjects];
    }
    return self;
}

- (void)dealloc {
    self.enumerator = nil;
    [super dealloc];
}

- (id)count {
    return NUMLONG(self.enumerator.count);
}

- (id)sequenceNumber {
    return NUMLONG(self.enumerator.sequenceNumber);
}

- (id)stale {
    return NUMBOOL(self.enumerator.stale);
}

- (id)next:(id)args {
    CBLQueryRow * row = [self.enumerator nextRow];
    return row ? [TDQueryRowProxy proxyWithQueryEnumerator:self queryRow:row] : nil;
}

- (id)getRow:(id)args {
    NSNumber * index;
    ENSURE_ARG_AT_INDEX(index, (NSArray *)args, 0, NSNumber)
    
    NSUInteger i = [index unsignedIntegerValue];
    if (i >= self.enumerator.count) {
        return [NSNull null];
    }
    
    CBLQueryRow * row = [self.enumerator rowAtIndex:i];
    return row ? [TDQueryRowProxy proxyWithQueryEnumerator:self queryRow:row] : nil;
}

- (void)reset:(id)args {
    [self.enumerator reset];
}

@end


@implementation TDQueryRowProxy

+ (instancetype)proxyWithQueryEnumerator:(TDQueryEnumeratorProxy *)enumerator queryRow:(CBLQueryRow *)row {
    return [[[TDQueryRowProxy alloc] initWithQueryEnumerator:enumerator queryRow:row] autorelease];
}

- (id)initWithQueryEnumerator:(TDQueryEnumeratorProxy *)enumerator queryRow:(CBLQueryRow *)row {
    if (self = [super init]) {
        self.queryEnumerator = enumerator;
        self.row = row;
    }
    return self;
}

- (void)dealloc {
    self.row = nil;
    [super dealloc];
}

- (id)database {
    return self.queryEnumerator.query.database;
}

- (id)key {
    return self.row.key;
}

- (id)value {
    return self.row.value;
}

- (id)documentID {
    return self.row.documentID;
}

- (id)sourceDocumentID {
    return self.row.sourceDocumentID;
}

- (id)documentRevisionID {
    return self.row.documentRevisionID;
}

- (id)getDocument:(id)args {
    return self.row.document ? [self.queryEnumerator.query.database _existingDocumentWithID:self.row.documentID] : nil;
}

- (id)documentProperties {
    return self.row.documentProperties;
}

-(id)keyAtIndex:(id)args {
    NSNumber * index;
    ENSURE_ARG_AT_INDEX(index, (NSArray *)args, 0, NSNumber)
    return [self.row keyAtIndex:[index unsignedIntegerValue]];
}

- (id)key0 {
    return self.row.key0;
}

- (id)key1 {
    return self.row.key1;
}

- (id)key2 {
    return self.row.key2;
}

- (id)key3 {
    return self.row.key3;
}

- (id)sequenceNumber {
    return NUMLONG(self.row.sequenceNumber);
}

- (id)conflictingRevisions {
    NSMutableArray * result = [NSMutableArray array];
    for (CBLSavedRevision * rev in self.row.conflictingRevisions) {
        [result addObject:[TDSavedRevisionProxy proxyWithDocument:[self.queryEnumerator.query.database _existingDocumentWithID:rev.document.documentID] savedRevision:rev]];
    }
    return result;
}

@end