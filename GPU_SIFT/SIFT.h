

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

@interface SIFT : UIView
{
@private
	
	EAGLContext *context;
	
	int width;
	int height;
	
	// OpenGL framebuffer pointers:
	GLuint detBuf[4], dogBuf[4][2], renderBuf, gxBuf[4], gyBuf[4], dispBuf, regBuf, winBuf, rotBuf, desBuf, desBuf2, edgeBuf, smoothBuf[4][4];
	
	// OpenGL texture pointers:
	GLuint pic, detTex[4], dogTex[4][2], gxTex[4], gyTex[4], gauss, gauss2, regTex, winTex, rotTex, desTex, desTex2, edgeTex, blankTex, smoothTex[4][4], smooth0, smooth1;
	
	// OpenGL program pointers:
	GLuint printer, grad, smoothDouble, smooth, dog, nms, edgeSuppression, orientation, mainOrientation, descriptor;
	// Program parameters location pointers:
	GLuint printerWritingPosition, printerReadingPosition, printerPic0;
	GLuint gradWritingPosition, gradReadingPosition, gradPic0, gradPic1, gradSigma, gradDirection;
	GLuint smoothDoubleWritingPosition, smoothDoubleReadingPosition, smoothDoubleGaussianCoeff, smoothDoubleDirection, smoothDoublePic0, smoothDoublePic1;
	GLuint smoothWritingPosition, smoothReadingPosition, smoothGaussianCoeff, smoothDirection, smoothPic0;
	GLuint dogWritingPosition, dogReadingPosition, dogPic0;
	GLuint nmsWritingPosition, nmsReadingPosition, nmsWidth, nmsHeight, nmsPic0, nmsPic1;
	GLuint edgeSuppressionWritingPosition, edgeSuppressionReadingPosition, edgeSuppressionPic0, edgeSuppressionPic1, edgeSuppressionWidth, edgeSuppressionHeight, edgeSuppressionScale, edgeSuppressionTheta;
	GLuint orientationWritingPosition, orientationReadingPosition0, orientationReadingPosition1, orientationPicGradx, orientationPicGrady, orientationPicGauss, orientationScale, orientationTheta;
	GLuint mainOrientationWritingPosition, mainOrientationReadingPosition, mainOrientationSize, mainOrientationPic0;
	GLuint descriptorWritingPosition, descriptorReadingPosition, descriptorSize, descriptorPic0;
	
	//A few other useful variables to initialize now:
	uint8_t ** nmsOut;
	
	//constants:
	int NB_OCT;
	float coeffDown0[60];
	float coeffDown1[60];
	float coeffUp0[60];
	float coeffUp1[60];
	float coeffDoG[8];
	float sigma[4];
	GLshort writingPosition[8];
	GLshort readingPosition[8];
	GLfloat gaussCoord[8];
}

- (instancetype _Nonnull)init;
- (void)initWithWidth:(int)picWidth Height:(int)picHeight Octaves:(int)oct;
- (NSMutableArray * _Nonnull)computeSiftOn:(CGImageRef _Nonnull)cgImage;

@end
