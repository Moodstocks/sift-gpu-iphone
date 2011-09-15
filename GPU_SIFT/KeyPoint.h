//Simple class to store and update keypoints.
//contains key point coordinates, scale, octave, main orientation and descriptor.


@interface KeyPoint : NSObject
{
	int x;
	int y;
	int level;
	float s;
	int t;
	uint8_t * d;

}

- (int) x;
- (int) y;
- (int) level;
- (int) t;
- (uint8_t *) d;
- (int) getX;
- (int) getY;
- (int) getLevel;
- (int) getT;
- (float) getS;
- (uint8_t *) getD;
- (void) initParamsX:(int)u Y:(int)v Level:(int)sig;
- (void) setTheta:(int)th;
- (void) setDesc:(uint8_t *)desc;
- (void) setS:(float)scale;
@end

