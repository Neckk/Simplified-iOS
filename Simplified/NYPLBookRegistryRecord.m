#import "NYPLBook.h"
#import "NYPLBookLocation.h"
#import "NYPLBookRegistryRecord.h"
#import "NYPLNull.h"
#import "NYPLOPDSEvent.h"

@interface NYPLBookRegistryRecord ()

@property (nonatomic) NYPLBook *book;
@property (nonatomic) NYPLBookLocation *location;
@property (nonatomic) NYPLBookState state;

@end

static NSString *const BookKey = @"metadata";
static NSString *const LocationKey = @"location";
static NSString *const StateKey = @"state";

@implementation NYPLBookRegistryRecord

- (instancetype)initWithBook:(NYPLBook *const)book
                    location:(NYPLBookLocation *const)location
                       state:(NYPLBookState)state
{
  self = [super init];
  if(!self) return nil;
  
  if(!book) {
    @throw NSInvalidArgumentException;
  }
  
  self.book = book;
  self.location = location;
  self.state = state;
  
  // If the book availability indicates that the book is held, make sure the state
  // reflects that. Otherwise, make sure it's not in the Holding state.
  // If the status of the book is unknown, don't override it in either direction.
  if(book.availabilityStatus & (NYPLBookAvailabilityStatusUnavailable | NYPLBookAvailabilityStatusReserved)) {
    self.state = NYPLBookStateHolding;
  } else {
    if (!((NYPLBookStateDownloadFailed |
           NYPLBookStateDownloading |
           NYPLBookStateDownloadNeeded |
           NYPLBookStateDownloadSuccessful |
           NYPLBookStateUsed) & self.state) && book.availabilityStatus != NYPLBookAvailabilityStatusUnknown) {
      self.state = NYPLBookStateDownloadNeeded;
    }
  }
  
  return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
  self = [super init];
  if(!self) return nil;
  
  self.book = [[NYPLBook alloc] initWithDictionary:dictionary[BookKey]];
  if(![self.book isKindOfClass:[NYPLBook class]]) return nil;
  
  self.location = [[NYPLBookLocation alloc]
                   initWithDictionary:NYPLNullToNil(dictionary[LocationKey])];
  if(self.location && ![self.location isKindOfClass:[NYPLBookLocation class]]) return nil;
  
  self.state = NYPLBookStateFromString(dictionary[StateKey]);
  
  return self;
}

- (NSDictionary *)dictionaryRepresentation
{
  return @{BookKey: [self.book dictionaryRepresentation],
           LocationKey: NYPLNullFromNil([self.location dictionaryRepresentation]),
           StateKey: NYPLBookStateToString(self.state)};
}

- (instancetype)recordWithBook:(NYPLBook *const)book
{
  return [[[self class] alloc] initWithBook:book location:self.location state:self.state];
}

- (instancetype)recordWithLocation:(NYPLBookLocation *const)location
{
  return [[[self class] alloc] initWithBook:self.book location:location state:self.state];
}

- (instancetype)recordWithState:(NYPLBookState const)state
{
  return [[[self class] alloc] initWithBook:self.book location:self.location state:state];
}

@end
