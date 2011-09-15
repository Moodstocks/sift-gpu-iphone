#include "KeyPoint.h"


@implementation KeyPoint

- (int) x
{
	return x;
}

- (int) y
{
	return y;
}

- (int) level
{
	return level;
}

- (int) t
{
	return t;
}

- (uint8_t *) d
{
	return d;
}

- (int) getX
{
	return x;
}

- (int) getY
{
	return y;
}

- (int) getLevel
{
	return level;
}

- (int) getT
{
	return t;
}

- (uint8_t *) getD
{
	return d;
}

- (float) getS
{
	return s;
}

- (void) initParamsX:(int)u Y:(int)v Level:(int)l
{
	x=u;
	y=v;
	level=l;
	s=1.6*pow(sqrt(sqrt(2)),(float)level);
}

- (void) setTheta:(int)th
{
	t=th;
}

- (void) setDesc:(uint8_t *)desc
{
	d = desc;
}

- (void) setS:(float)scale
{
	s=scale;
}

@end