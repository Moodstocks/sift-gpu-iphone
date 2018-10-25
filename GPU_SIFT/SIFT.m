
#include <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include "SIFT.h"
#define STRINGIFY(A) #A

#ifdef _ARM_ARCH_7
	#include <arm_neon.h>
#endif

#include "KeyPoint.h"

@interface SIFT (EAGLViewSprite)

- (void)initWithWidth:(int)width Height:(int)height Octaves:(int)oct;

@end

@implementation SIFT

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (instancetype _Nonnull)init
{
    if (self = [super init]) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if(!context || ![EAGLContext setCurrentContext:context]) {
            return nil;
        }
        
        [EAGLContext setCurrentContext:context];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder
{
	if((self = [super initWithCoder:coder])) {
		// Get the layer
		CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
			
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		
		if(!context || ![EAGLContext setCurrentContext:context]) {
			return nil;
		}
		
		[EAGLContext setCurrentContext:context];
	}

    return self;
}

#ifdef _ARM_ARCH_7
//RGB to 4 x grayscale conversion using NEON
void neon_convert (uint8_t * __restrict dest, uint8_t * __restrict src, int width, int height)
{
	int i;
	int j;
	uint8x8_t rfac = vdup_n_u8 (77);
	uint8x8_t gfac = vdup_n_u8 (151);
	uint8x8_t bfac = vdup_n_u8 (28);
	src += (height - 1) * width * 4;
	
	// Convert per eight pixels
	for (i = height - 1; i >= 0; --i)
	{
		for (j = 0; j < width / 8; ++j)
		{
			uint16x8_t temp;
			uint8x8x4_t rgb = vld4_u8 (src);
			uint8x8x4_t result;
			
			temp = vmull_u8 (rgb.val[0],      bfac);
			temp = vmlal_u8 (temp,rgb.val[1], gfac);
			temp = vmlal_u8 (temp,rgb.val[2], rfac);
			
			result.val[0] = vshrn_n_u16 (temp, 8);
			result.val[1] = vshrn_n_u16 (temp, 8);
			result.val[2] = vshrn_n_u16 (temp, 8);
			result.val[3] = vshrn_n_u16 (temp, 8);
			
			vst4_u8 (dest, result);
			src  += 8*4;
			dest += 8*4;
		}
		src -= 8 * width;
	}
}
#else
void neon_convert (uint8_t * __restrict dest, uint8_t * __restrict src, int width, int height)
{
	int k = (height - 1) * width * 4;
	int l = 0;
	for (int i = height - 1; i >= 0; --i)
	{
		for (int j = 0; j < width; ++j)
		{
			//uint8_t color = 0;
			uint8_t color = (77 * src[k] + 151 * src[k + 1] + 28 * src[k + 2]) / 256;
			dest[l] = color;
			dest[l + 1] = color;
			dest[l + 2] = color;
			dest[l + 3] = color;
			
			k+=4;
			l+=4;
		}
		k -= 8 * width;
	}
}
#endif


//descriptor normalization and writing to structure
void reorganize (uint8_t * reorgOut, uint8_t * desOut, int nb, int sqSize)
{
	for (int i = 0; i < nb; i++) {
		int firstIndex = 16 * (i % sqSize + (i / sqSize) * 4 * sqSize);
		for (int j = 0; j < 4; j++) {
			reorgOut[128*i+32*j+0] = desOut[firstIndex+j*16*sqSize+0]/16;
			reorgOut[128*i+32*j+1] = desOut[firstIndex+j*16*sqSize+0];
			reorgOut[128*i+32*j+2] = desOut[firstIndex+j*16*sqSize+1]/16;
			reorgOut[128*i+32*j+3] = desOut[firstIndex+j*16*sqSize+1];
			reorgOut[128*i+32*j+4] = desOut[firstIndex+j*16*sqSize+2]/16;
			reorgOut[128*i+32*j+5] = desOut[firstIndex+j*16*sqSize+2];
			reorgOut[128*i+32*j+6] = desOut[firstIndex+j*16*sqSize+3]/16;
			reorgOut[128*i+32*j+7] = desOut[firstIndex+j*16*sqSize+3];
			reorgOut[128*i+32*j+8] = desOut[firstIndex+j*16*sqSize+4]/16;
			reorgOut[128*i+32*j+9] = desOut[firstIndex+j*16*sqSize+4];
			reorgOut[128*i+32*j+10] = desOut[firstIndex+j*16*sqSize+5]/16;
			reorgOut[128*i+32*j+11] = desOut[firstIndex+j*16*sqSize+5];
			reorgOut[128*i+32*j+12] = desOut[firstIndex+j*16*sqSize+6]/16;
			reorgOut[128*i+32*j+13] = desOut[firstIndex+j*16*sqSize+6];
			reorgOut[128*i+32*j+14] = desOut[firstIndex+j*16*sqSize+7]/16;
			reorgOut[128*i+32*j+15] = desOut[firstIndex+j*16*sqSize+7];
			reorgOut[128*i+32*j+16] = desOut[firstIndex+j*16*sqSize+8]/16;
			reorgOut[128*i+32*j+17] = desOut[firstIndex+j*16*sqSize+8];
			reorgOut[128*i+32*j+18] = desOut[firstIndex+j*16*sqSize+9]/16;
			reorgOut[128*i+32*j+19] = desOut[firstIndex+j*16*sqSize+9];
			reorgOut[128*i+32*j+20] = desOut[firstIndex+j*16*sqSize+10]/16;
			reorgOut[128*i+32*j+21] = desOut[firstIndex+j*16*sqSize+10];
			reorgOut[128*i+32*j+22] = desOut[firstIndex+j*16*sqSize+11]/16;
			reorgOut[128*i+32*j+23] = desOut[firstIndex+j*16*sqSize+11];
			reorgOut[128*i+32*j+24] = desOut[firstIndex+j*16*sqSize+12]/16;
			reorgOut[128*i+32*j+25] = desOut[firstIndex+j*16*sqSize+12];
			reorgOut[128*i+32*j+26] = desOut[firstIndex+j*16*sqSize+13]/16;
			reorgOut[128*i+32*j+27] = desOut[firstIndex+j*16*sqSize+13];
			reorgOut[128*i+32*j+28] = desOut[firstIndex+j*16*sqSize+14]/16;
			reorgOut[128*i+32*j+29] = desOut[firstIndex+j*16*sqSize+14];
			reorgOut[128*i+32*j+30] = desOut[firstIndex+j*16*sqSize+15]/16;
			reorgOut[128*i+32*j+31] = desOut[firstIndex+j*16*sqSize+15];
		}
	}
}
	
//normalization as described in SIFT paper: normalize, clamp to [0 , 0.2], normalize again, quantize on [0, 0.5]
void normalize(NSMutableArray * tab, uint8_t * r, int nb)
{
	for (int i = 0; i < nb; i++) {
		//norm
		float s = 0.0;
		for (int j = 0; j < 128; j++) {
			s += (float)(r[128 * i + j] * r[128 * i + j]);
		}
		s = sqrt(s);
		//clamp
		float * clamp = (float *) calloc(128, sizeof(float));
		for (int j = 0; j < 128; j++) {
			float v = (float)r[128*i+j]/s;
			clamp[j] = v>0.2 ? 0.2 : v;
		}
		//norm
		s = 0.0;
		for (int j = 0; j < 128; j++) {
			s += clamp[j] * clamp[j];
		}
		s = sqrt(s)/255.0;
		//output
		uint8_t * values = (uint8_t *) calloc(128, sizeof(uint8_t));
		for (int j = 0; j < 128; j++) {
			values[j] = (int)(2.0*clamp[j]/s);
		}
		[[tab objectAtIndex:i] setDesc:values];
	}
}

//reads a text file into a buffer.
//necessary to read shader file
const char* filetobuf(const char *file)
{
    FILE *fptr;
    long length;
    char *buf;
	
    fptr = fopen(file, "rb"); 
    if (!fptr) 
        return NULL;
    fseek(fptr, 0, SEEK_END); 
    length = ftell(fptr); 
    buf = (char*)malloc(length+1);
    fseek(fptr, 0, SEEK_SET); 
    fread(buf, length, 1, fptr); 
    fclose(fptr);
    buf[length] = 0; 
	
    return buf;
}

// This function compiles shaders and checks that everything went good.
GLuint BuildShader(NSString* filename, GLenum shaderType)
{
	NSString* ext = shaderType==GL_VERTEX_SHADER ? @"vsh" : @"fsh";
	
    const char *file = [[[NSBundle mainBundle] pathForResource:filename ofType:ext inDirectory:nil] cStringUsingEncoding:NSUTF8StringEncoding];
	const char* source = filetobuf(file);
    GLuint shaderHandle = glCreateShader(shaderType);
    glShaderSource(shaderHandle, 1, &source, 0);
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    
    if (compileSuccess == GL_FALSE) {
        exit(1);
    }
    
    return shaderHandle;
}


// This function associates a vertex shader and a pixel shader
GLuint BuildProgram(NSString* vertexShaderFilename, NSString* fragmentShaderFilename)
{
    GLuint vertexShader = BuildShader(vertexShaderFilename, GL_VERTEX_SHADER);
    GLuint fragmentShader = BuildShader(fragmentShaderFilename, GL_FRAGMENT_SHADER);
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        exit(2);
    }
	return programHandle;
}


// Initialize the class
- (void)initWithWidth:(int)picWidth Height:(int)picHeight Octaves:(int)oct
{
	
	width = picWidth;
	height = picHeight;
	NB_OCT = oct;
		
	// Full screen writing coordinates
	writingPosition[0] = -1.0;
    writingPosition[1] = -1.0;
    writingPosition[2] = 1.0;
    writingPosition[3] = -1.0;
    writingPosition[4] = -1.0;
    writingPosition[5] = 1.0;
    writingPosition[6] = 1.0;
    writingPosition[7] = 1.0;
	
	// Fulle screen reading coordinates
	readingPosition[0] = 0.0;
    readingPosition[1] = 0.0;
    readingPosition[2] = 1.0;
    readingPosition[3] = 0.0;
    readingPosition[4] = 0.0;
    readingPosition[5] = 1.0;
    readingPosition[6] = 1.0;
    readingPosition[7] = 1.0;

	
	// kernel values
	const float sigmas[7] = {1.34543, 1.6, 1.90273, 2.26274, 2.69087, 3.2, 3.80546};
	const float sigmaDown[4] = {sigmas[0], sigmas[1], sigmas[2], sigmas[3]};
	const float sigmaUp[4] = {sigmas[3], sigmas[4], sigmas[5], sigmas[6]};
	sigma[0] = sigmas[1]; sigma[1] = sigmas[2]; sigma[2] = sigmas[3]; sigma[3] = sigmas[4]; 
	
	for (int i = 0; i < 15; i++) {
		for (int j = 0; j < 4; j++) {
			coeffDown0[4*i+j] = exp(-(float)(i)*(float)(i)/(2.0*sigmaDown[j]*sigmaDown[j]))/sqrt(2.0*3.14159*sigmaDown[j]*sigmaDown[j]);
			coeffDown1[4*i+j] = i==0 ? 1.0 : exp(-(float)(i)*(float)(i)/(2.0*sigmaDown[j]*sigmaDown[j]))/sqrt(2.0*3.14159*sigmaDown[j]*sigmaDown[j]);
		}
	}
	for (int i = 0; i < 15; i++) {
		for (int j = 0; j < 4; j++) {
			coeffUp0[4*i+j] = exp(-(float)(i)*(float)(i)/(2.0*sigmaUp[j]*sigmaUp[j]))/sqrt(2.0*3.14159*sigmaUp[j]*sigmaUp[j]);
			coeffUp1[4*i+j] = i==0 ? 1.0 : exp(-(float)(i)*(float)(i)/(2.0*sigmaUp[j]*sigmaUp[j]))/sqrt(2.0*3.14159*sigmaUp[j]*sigmaUp[j]);
		}
	}

	float sigmaDoG = 1.8;
	for (int i = 0; i < 8; i++) {
		coeffDoG[i] = exp(-(float)(i)*(float)(i)/(2.0*sigmaDoG*sigmaDoG))/sqrt(2.0*3.14159*sigmaDoG*sigmaDoG);
	}

	
	//gaussian for orientation computation
	glGenTextures(1, &gauss);
	glBindTexture(GL_TEXTURE_2D, gauss);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	
	uint8_t* gaussData = (uint8_t*) calloc(16*16, sizeof(uint8_t));
	for (int i =- 8; i < 8; i++) {
		for (int j =- 8; j < 8; j++) {
			gaussData[16*(i+8)+j+8] = (uint8_t)(255.0*exp(-(float)((i+0.5)*(i+0.5) + (j+0.5)*(j+0.5))/(2.0*2.25)));
		}
	}
	glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, 16, 16, 0, GL_ALPHA, GL_UNSIGNED_BYTE, gaussData);
	free(gaussData);
	
	//gaussian for descriptor weighting
	glGenTextures(1, &gauss2);
	glBindTexture(GL_TEXTURE_2D, gauss2);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	uint8_t* gaussData2=(uint8_t*) calloc(32*32, sizeof(uint8_t));
	for (int i =- 16; i < 16; i++) {
		for (int j =- 16; j < 16; j++) {
			gaussData2[32*(i+16)+j+16] = (uint8_t)(255.0*exp(-(float)((i+0.5)*(i+0.5) + (j+0.5)*(j+0.5))/(2.0*64.0)));
		}
	}
	glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, 32, 32, 0, GL_ALPHA, GL_UNSIGNED_BYTE, gaussData2);
	free(gaussData2);
	
	// Special texture coordinates for this gaussian:
	
	gaussCoord[0] = 5.0/32.0;
    gaussCoord[1] = 5.0/32.0;
    gaussCoord[2] = 27.0/32.0;
    gaussCoord[3] = 5.0/32.0;
    gaussCoord[4] = 5.0/32.0;
    gaussCoord[5] = 27.0/32.0;
    gaussCoord[6] = 27.0/32.0;
    gaussCoord[7] = 27.0/32.0;
		
	
	
	// ------------------- SHADERS INITIALIZATION PART ----------------------
	/* Builds shaders and sends them data, or at least locates the
	 shader variable position so data can be sent to it later */
	
	//printer init
	printer = BuildProgram(@"vertex",@"printer");
	glUseProgram(printer);
	printerWritingPosition = glGetAttribLocation(printer, "writingPosition");
	glVertexAttribPointer(printerWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(printerWritingPosition);
	printerReadingPosition = glGetAttribLocation(printer, "readingPosition");
	glVertexAttribPointer(printerReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(printerReadingPosition);
	printerPic0 = glGetUniformLocation(printer, "pic");
	
	
	//gradient init
	grad = BuildProgram(@"vertex",@"gradient");
	glUseProgram(grad);
	gradWritingPosition = glGetAttribLocation(grad, "writingPosition");
	glVertexAttribPointer(gradWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(gradWritingPosition);
	gradReadingPosition = glGetAttribLocation(grad, "readingPosition");
	glVertexAttribPointer(gradReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(gradReadingPosition);
	gradPic0 = glGetUniformLocation(grad, "pic0");
	gradPic1 = glGetUniformLocation(grad, "pic1");
	gradSigma = glGetUniformLocation(grad, "sigma");
	glUniform1fv(gradSigma, 4, sigma);
	gradDirection = glGetUniformLocation(grad, "direction");
	
	//smoothDouble init, computes high precision smoothing in 2 pass
	smoothDouble = BuildProgram(@"vertex", @"smoothDouble");
	glUseProgram(smoothDouble);
	smoothDoubleWritingPosition = glGetAttribLocation(smoothDouble, "writingPosition");
	glVertexAttribPointer(smoothDoubleWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(smoothDoubleWritingPosition);
	smoothDoubleReadingPosition = glGetAttribLocation(smoothDouble, "readingPosition");
	glVertexAttribPointer(smoothDoubleReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(smoothDoubleReadingPosition);
	smoothDoubleGaussianCoeff = glGetUniformLocation(smoothDouble, "gaussianCoeff");
	smoothDoubleDirection = glGetUniformLocation(smoothDouble, "direction"); 
	smoothDoublePic1 = glGetUniformLocation(smoothDouble, "pic1");
	smoothDoublePic0 = glGetUniformLocation(smoothDouble, "pic0");
	
	//smooth init, more approximate version used to smooth DoG results
	smooth = BuildProgram(@"vertex", @"smooth");
	glUseProgram(smooth);
	smoothWritingPosition = glGetAttribLocation(smooth, "writingPosition");
	glVertexAttribPointer(smoothWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(smoothWritingPosition);
	smoothReadingPosition = glGetAttribLocation(smooth, "readingPosition");
	glVertexAttribPointer(smoothReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(smoothReadingPosition);
	smoothGaussianCoeff = glGetUniformLocation(smooth, "gaussianCoeff");
	smoothDirection = glGetUniformLocation(smooth, "direction"); 
	smoothPic0 = glGetUniformLocation(smooth, "pic");
	
	//dog init
	dog=BuildProgram(@"vertex", @"dog");
	glUseProgram(dog);
	dogWritingPosition = glGetAttribLocation(dog, "writingPosition");
	glVertexAttribPointer(dogWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(dogWritingPosition);
	dogReadingPosition = glGetAttribLocation(dog, "readingPosition");
	glVertexAttribPointer(dogReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(dogReadingPosition);
	dogPic0 = glGetUniformLocation(dog, "pic");

	
	//NMS init
	nms=BuildProgram(@"vertex", @"nms");
	glUseProgram(nms);
	nmsWritingPosition = glGetAttribLocation(nms, "writingPosition");
	glVertexAttribPointer(nmsWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(nmsWritingPosition);
	nmsReadingPosition = glGetAttribLocation(nms, "readingPosition");
	glVertexAttribPointer(nmsReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(nmsReadingPosition);
	nmsWidth = glGetUniformLocation(nms, "width");
	nmsHeight = glGetUniformLocation(nms, "height");
	nmsPic0 = glGetUniformLocation(nms, "pic0");
	nmsPic1 = glGetUniformLocation(nms, "pic1");
	

	//Edge Response Suppression init
	edgeSuppression = BuildProgram(@"vertex0", @"edgeSuppression");
	glUseProgram(edgeSuppression);
	edgeSuppressionWritingPosition = glGetAttribLocation(edgeSuppression, "writingPosition");
	glEnableVertexAttribArray(edgeSuppressionWritingPosition);
	edgeSuppressionPic0 = glGetUniformLocation(edgeSuppression, "pic0");
	edgeSuppressionPic1 = glGetUniformLocation(edgeSuppression, "pic1");
	edgeSuppressionWidth = glGetUniformLocation(edgeSuppression, "width");
	edgeSuppressionHeight = glGetUniformLocation(edgeSuppression, "height");
	edgeSuppressionScale = glGetUniformLocation(edgeSuppression, "scale");
	edgeSuppressionReadingPosition = glGetUniformLocation(edgeSuppression, "readingPosition");
	
	
	//orientation init
	orientation = BuildProgram(@"vertex2", @"orientation");
	glUseProgram(orientation);
	orientationWritingPosition = glGetAttribLocation(orientation, "writingPosition");
	glEnableVertexAttribArray(orientationWritingPosition);
	orientationReadingPosition0 = glGetAttribLocation(orientation, "readingPositionGrad");
	glEnableVertexAttribArray(orientationReadingPosition0);
	orientationReadingPosition1 = glGetAttribLocation(orientation, "readingPositionGauss");
	glVertexAttribPointer(orientationReadingPosition1, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(orientationReadingPosition1);
	orientationPicGradx = glGetUniformLocation(orientation, "gradx");
	orientationPicGrady = glGetUniformLocation(orientation, "grady");
	orientationPicGauss = glGetUniformLocation(orientation, "gauss");
	orientationScale = glGetUniformLocation(orientation, "scale");
	orientationTheta = glGetUniformLocation(orientation, "theta");
	
	
	//main orientation init
	mainOrientation = BuildProgram(@"vertex", @"mainOrientation");
	glUseProgram(mainOrientation);
	mainOrientationWritingPosition = glGetAttribLocation(mainOrientation, "writingPosition");
	glVertexAttribPointer(mainOrientationWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(mainOrientationWritingPosition);
	mainOrientationReadingPosition = glGetAttribLocation(mainOrientation, "readingPosition");
	glVertexAttribPointer(mainOrientationReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(mainOrientationReadingPosition);
	mainOrientationSize = glGetUniformLocation(mainOrientation, "sqSize");
	mainOrientationPic0 = glGetUniformLocation(mainOrientation, "pic0");
	
	//descriptor init
	descriptor = BuildProgram(@"vertex", @"descriptor");
	glUseProgram(descriptor);
	descriptorWritingPosition = glGetAttribLocation(descriptor, "writingPosition");
	glVertexAttribPointer(descriptorWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glEnableVertexAttribArray(descriptorWritingPosition);
	descriptorReadingPosition = glGetAttribLocation(descriptor, "readingPosition");
	glVertexAttribPointer(descriptorReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glEnableVertexAttribArray(descriptorReadingPosition);
	descriptorSize = glGetUniformLocation(descriptor, "sqSize");
	descriptorPic0 = glGetUniformLocation(descriptor, "pic0");

	// ---------------------- BUFFERS AND TEXTURES INITIALIZATION --------------------
	

	glGenTextures(1, &regTex);
	glBindTexture(GL_TEXTURE_2D, regTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &regBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, regBuf);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, regTex, 0);

	glGenTextures(1, &edgeTex);
	glBindTexture(GL_TEXTURE_2D, edgeTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &edgeBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, edgeBuf);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, edgeTex, 0);
	
	glGenTextures(1, &winTex);
	glBindTexture(GL_TEXTURE_2D, winTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &winBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, winBuf);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, winTex, 0);
	
	glGenTextures(1, &rotTex);
	glBindTexture(GL_TEXTURE_2D, rotTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &rotBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, rotBuf);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rotTex, 0);
	
	glGenTextures(1, &desTex);
	glBindTexture(GL_TEXTURE_2D, desTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glGenFramebuffers(1, &desBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, desBuf);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, desTex, 0);

	glGenTextures(1, &pic);
	glBindTexture(GL_TEXTURE_2D, pic);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);

	
	
	
	uint8_t * blankData = (uint8_t *) calloc(width*height*4, sizeof(uint8_t));
	for (int i=0; i<width*height*4; i++) {
		blankData[i]=128;
	}
	glGenTextures(1, &blankTex);
	glBindTexture(GL_TEXTURE_2D, blankTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, blankData);
	
	
	// "classical" buffer, not framebuffer
	//uint8_t *nmsOut[NB_OCT];
	nmsOut = calloc(NB_OCT, sizeof(uint8_t*));
	
	for (int i=0; i<NB_OCT; i++) {
		
		glGenFramebuffers(1, &dogBuf[i][0]);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glGenTextures(1, &dogTex[i][0]);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, dogTex[i][0], 0);
		
		glGenFramebuffers(1, &dogBuf[i][1]);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][1]);
		glGenTextures(1, &dogTex[i][1]);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, dogTex[i][1], 0);
		
		glGenFramebuffers(1, &detBuf[i]);
		glBindFramebuffer(GL_FRAMEBUFFER, detBuf[i]);
		glGenTextures(1, &detTex[i]);
		glBindTexture(GL_TEXTURE_2D, detTex[i]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, detTex[i], 0);
		
		glGenFramebuffers(1, &gxBuf[i]);
		glBindFramebuffer(GL_FRAMEBUFFER, gxBuf[i]);
		glGenTextures(1, &gxTex[i]);
		glBindTexture(GL_TEXTURE_2D, gxTex[i]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, gxTex[i], 0);
		
		glGenFramebuffers(1, &gyBuf[i]);
		glBindFramebuffer(GL_FRAMEBUFFER, gyBuf[i]);
		glGenTextures(1, &gyTex[i]);
		glBindTexture(GL_TEXTURE_2D, gyTex[i]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, gyTex[i], 0);
		
		glGenFramebuffers(1, &smoothBuf[i][0]);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][0]);
		glGenTextures(1, &smoothTex[i][0]);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, smoothTex[i][0], 0);
		
		glGenFramebuffers(1, &smoothBuf[i][1]);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][1]);
		glGenTextures(1, &smoothTex[i][1]);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][1]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, smoothTex[i][1], 0);
		
		glGenFramebuffers(1, &smoothBuf[i][2]);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][2]);
		glGenTextures(1, &smoothTex[i][2]);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][2]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, smoothTex[i][2], 0);
		
		glGenFramebuffers(1, &smoothBuf[i][3]);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][3]);
		glGenTextures(1, &smoothTex[i][3]);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][3]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width>>i, height>>i, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, smoothTex[i][3], 0);
		
		nmsOut[i] = (uint8_t *) calloc((width>>i)*(height>>i)*4, sizeof(uint8_t));

	}
	
	glGenFramebuffers(1, &dispBuf);
	glBindFramebuffer(GL_FRAMEBUFFER, dispBuf);
	glGenRenderbuffers(1, &renderBuf);
	glBindRenderbuffer(GL_RENDERBUFFER, renderBuf);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuf);
	[context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
	
}





- (NSMutableArray * _Nonnull)computeSiftOn:(CGImageRef _Nonnull)cgImage
{
		
	//for debugging
	NSTimeInterval tinit= [[NSDate date] timeIntervalSince1970];
	int count[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

	//initializing a few variables
	uint8_t *originalData;
	originalData = (uint8_t *) calloc(width * height * 4, sizeof(uint8_t));
	uint8_t *grayData;
	grayData = (uint8_t *) calloc(width * height * 4, sizeof(uint8_t));
	
	//Loading and converting image
	CGDataProviderRef dataRef = CGImageGetDataProvider(cgImage);
	CFDataRef data = CGDataProviderCopyData(dataRef);
	originalData = (GLubyte *) CFDataGetBytePtr(data);
	neon_convert(grayData, originalData, width, height);
	glBindTexture(GL_TEXTURE_2D, pic);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, grayData);
	
	
	// --------------------- DETECTION ----------------
	//Loop on octaves
    
    double tdetect0 = [[NSDate date] timeIntervalSince1970];
    
	int w = width;
	int h = height;
	for (int i=0; i<NB_OCT; i++) {
		
		glViewport(0, 0, w, h);
	
		// First 4 "Half levels"
		//horizontal smoothing
		glUseProgram(smoothDouble);
		glVertexAttribPointer(smoothDoubleWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
		glVertexAttribPointer(smoothDoubleReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 1.0/(float)w, 0.0);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffDown0);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//second pass
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, -1.0/(float)w, 0.0);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffDown1);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][1]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//vertical smoothing
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 0.0, 1.0/(float)h);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffDown0);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		//second pass
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 0.0, -1.0/(float)h);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffDown1);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		
		// Last 4 "Half levels"
		//horizontal smoothing
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 1.0/(float)w, 0.0);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffUp0);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		//second pass
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, pic);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, -1.0/(float)w, 0.0);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffUp1);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][1]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//vertical smoothing
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 0.0, 1.0/(float)h);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffUp0);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		//second pass
		glUseProgram(smoothDouble);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(smoothDoublePic1,0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glUniform1i(smoothDoublePic0,1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(smoothDoubleDirection, 0.0, -1.0/(float)h);
		glUniform4fv(smoothDoubleGaussianCoeff, 15, coeffUp1);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][1]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		
		//While looping on octaves, we compute the gradients
		//horizontal grad
		glUseProgram(grad);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][0]);
		glUniform1i(gradPic0, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][1]);
		glUniform1i(gradPic1, 1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(gradDirection, 1.0/(float)w, 0.0);
		glBindFramebuffer(GL_FRAMEBUFFER, gxBuf[i]);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//vertical grad
		glUseProgram(grad);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][0]);
		glUniform1i(gradPic0, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][1]);
		glUniform1i(gradPic1, 1);
		glActiveTexture(GL_TEXTURE0);
		glUniform2f(gradDirection, 0.0, 1.0/(float)h);
		glBindFramebuffer(GL_FRAMEBUFFER, gyBuf[i]);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		
		//DoG computation
		//First 3 levels
		glUseProgram(dog);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][0]);
		glUniform1i(dogPic0, 0);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][2]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		glUseProgram(smooth);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][2]);
		glUniform1i(smoothPic0, 0);
		glUniform1fv(smoothGaussianCoeff, 8, coeffDoG);
		glUniform2f(smoothDirection, 1.0/(float)w, 0.0);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glUseProgram(smooth);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][0]);
		glUniform1i(smoothPic0, 0);
		glUniform1fv(smoothGaussianCoeff, 8, coeffDoG);
		glUniform2f(smoothDirection, 0.0, 1.0/(float)h);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][0]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		
	
		//Next and last 3 levels
		glUseProgram(dog);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][1]);
		glUniform1i(dogPic0, 0);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][3]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		glUseProgram(smooth);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][3]);
		glUniform1i(smoothPic0, 0);
		glUniform1fv(smoothGaussianCoeff, 8, coeffDoG);
		glUniform2f(smoothDirection, 1.0/(float)w, 0.0);
		glBindFramebuffer(GL_FRAMEBUFFER, smoothBuf[i][1]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glUseProgram(smooth);
		glBindTexture(GL_TEXTURE_2D, smoothTex[i][1]);
		glUniform1i(smoothPic0, 0);
		glUniform1fv(smoothGaussianCoeff, 8, coeffDoG);
		glUniform2f(smoothDirection, 0.0, 1.0/(float)h);
		glBindFramebuffer(GL_FRAMEBUFFER, dogBuf[i][1]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//NMS
		glUseProgram(nms);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][0]);
		glUniform1i(nmsPic0, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[i][1]);
		glUniform1i(nmsPic1, 1);
		glActiveTexture(GL_TEXTURE0);
		glUniform1f(nmsWidth, (float)w);
		glUniform1f(nmsHeight, (float)h);
		glBindFramebuffer(GL_FRAMEBUFFER, detBuf[i]);
		glClear(GL_COLOR_BUFFER_BIT);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
		//readback to CPU
		glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, nmsOut[i]);
		
		
		//Next octave
		w>>=1;
		h>>=1;
		
	}



	//CPU Processing part: 
	// we must explore the image and find the coordinates and scales of keypoints,
	// then store them in an array 

	w = width;
	h = height;
	NSMutableArray *tab = [NSMutableArray arrayWithCapacity:0];
	for (int i=0; i<NB_OCT; i++) {
		for (int j=0; j<h; j++) {
			for (int k=0; k<w; k++) {
				for (int l=0; l<4; l++) {
					if (nmsOut[i][4*(w*j+k)+l]>0) {
						KeyPoint *key = [KeyPoint new];
						[key initParamsX:(k<<i) Y:(j<<i) Level:l+4*i];
						int regSize = (int)(1.0*sigma[l]*exp2(i)); 
						if ([key getX]>regSize && [key getX]<width-regSize && [key getY]>regSize && [key getY]<height-regSize ) {
							[tab addObject:key];
						}
					}
				}
			}
		}
		w>>=1;
		h>>=1;
	}
	//sqSize = size of the square we will use to display the tiled regions of interest
	int sqSize=(int)ceil(sqrt((float)[tab count]));
	int nb = (int)[tab count];
	

	uint8_t * edgeOut = (uint8_t *) calloc(sqSize * sqSize *4, sizeof(uint8_t));
	// back to GPU for edge response and low contrast response suppression
	// first we extract the 3 x 3 pixels (at octave size) region around each keypoint
	// and store them in one single texture.
	glViewport(0, 0, sqSize, sqSize);
	glBindFramebuffer(GL_FRAMEBUFFER, edgeBuf);
	glClear(GL_COLOR_BUFFER_BIT);
	glBindTexture(GL_TEXTURE_2D, edgeTex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sqSize, sqSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	for (int i=0; i<nb; i++) {
		KeyPoint * key = [tab objectAtIndex:i];
		int o = [key getLevel]/4;
		int s = [key getLevel]%4;
		float w = (float)width/(float)exp2(o);
		float h = (float)height/(float)exp2(o);
		float x = (float)[key getX]/(float)width;
		float y = (float)[key getY]/(float)height;
		
		glUseProgram(edgeSuppression);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, dogTex[o][0]);
		glUniform1i(edgeSuppressionPic0, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, dogTex[o][1]);
		glUniform1i(edgeSuppressionPic1, 1);
		glActiveTexture(GL_TEXTURE0);
		glUniform1f(edgeSuppressionWidth, (float)w);
		glUniform1f(edgeSuppressionHeight, (float)h);
		glUniform1i(edgeSuppressionScale, s);
		glUniform2f(edgeSuppressionReadingPosition, x, y);
		
		GLfloat vCoords[] = {
			(float)(i%sqSize)*2.0/(float)sqSize-1.0, (float)(i/sqSize)*2.0/(float)sqSize-1.0,
			(float)(i%sqSize+1)*2.0/(float)sqSize-1.0, (float)(i/sqSize)*2.0/(float)sqSize-1.0,
			(float)(i%sqSize)*2.0/(float)sqSize-1.0, (float)(i/sqSize+1)*2.0/(float)sqSize-1.0,
			(float)(i%sqSize+1)*2.0/(float)sqSize-1.0, (float)(i/sqSize+1)*2.0/(float)sqSize-1.0,
		};
		glVertexAttribPointer(edgeSuppressionWritingPosition, 2, GL_FLOAT, GL_FALSE, 0, vCoords);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	}
				
	//readback to CPU for processing
	glReadPixels(0, 0, sqSize, sqSize, GL_RGBA, GL_UNSIGNED_BYTE, edgeOut);
	// discard the pixels that don't pass the test.
	NSMutableIndexSet * discard = [NSMutableIndexSet indexSet];
	for (int i=0; i<nb; i++)
	{
		int discarded = edgeOut[4*i];
		if (discarded>200) {
			[discard addIndex:i];
		}
	}
	[tab removeObjectsAtIndexes:discard];
    NSLog(@"Discarding %lu keypoints",(unsigned long)[discard count]);
	sqSize=(int)ceil(sqrt((float)[tab count]));
	nb=(int)[tab count];
	
    double tdetect = [[NSDate date] timeIntervalSince1970]-tdetect0;
    
    double tori0 = [[NSDate date] timeIntervalSince1970];
    
	//back to GPU for orientation computation
	glViewport(0, 0, 16*sqSize, 16*sqSize);
	glBindFramebuffer(GL_FRAMEBUFFER, regBuf);
	glClear(GL_COLOR_BUFFER_BIT);
	glBindTexture(GL_TEXTURE_2D, regTex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 16*sqSize, 16*sqSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);


	//we tile the regions of interest in one single texture, and compute for each pixel
	//its orientation and weighted magnitude.
	for (int i=0; i<nb; i++) {
		KeyPoint* key = [tab objectAtIndex:i];
		int o = [key getLevel]/4;
		int s = [key getLevel]%4;
		float sig = sigma[s];
		float w = (float)(width>>o);
		float h = (float)(height>>o);
		GLfloat x = (float)[key getX]/(float)width;
		GLfloat y = (float)[key getY]/(float)height;
		glUseProgram(orientation);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, gxTex[o]);
		glUniform1i(orientationPicGradx, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, gyTex[o]);
		glUniform1i(orientationPicGrady, 1);
		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, gauss);
		glUniform1i(orientationPicGauss, 2);
		glActiveTexture(GL_TEXTURE0);
		glUniform1i(orientationScale, s);
		glUniform1i(orientationTheta, 0);
		GLfloat regCoord[] = 
		{
			x-(8.0*sig)/(float)w, y-(8.0*sig)/(float)h,
			x+(8.0*sig)/(float)w, y-(8.0*sig)/(float)h,
			x-(8.0*sig)/(float)w, y+(8.0*sig)/(float)h,
			x+(8.0*sig)/(float)w, y+(8.0*sig)/(float)h,
		};
		double minX=(double)(i%sqSize)/(double)sqSize*2.0-1.0;
		double maxX=minX+2.0/(double)sqSize;
		double minY=(double)(i/sqSize)/(double)sqSize*2.0-1.0;
		double maxY=minY+2.0/(double)sqSize;
		GLfloat regVertexCoord[] = 
		{
			minX, minY,
			maxX, minY,
			minX, maxY,
			maxX, maxY,
		};
		glVertexAttribPointer(orientationReadingPosition0, 2, GL_FLOAT, GL_FALSE, 0, regCoord);
		glVertexAttribPointer(orientationWritingPosition, 2, GL_FLOAT, GL_FALSE, 0, regVertexCoord);
		glVertexAttribPointer(orientationReadingPosition1, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	}
	
	//we compute the main orientation from the previous texture.
	glViewport(0, 0, sqSize, sqSize);
	glBindTexture(GL_TEXTURE_2D, winTex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, sqSize, sqSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	glUseProgram(mainOrientation);
	glBindTexture(GL_TEXTURE_2D, regTex);
	glUniform1i(mainOrientationPic0, 0);
	glVertexAttribPointer(mainOrientationWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glVertexAttribPointer(mainOrientationReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glUniform1i(mainOrientationSize, sqSize);
	glBindFramebuffer(GL_FRAMEBUFFER, winBuf);
	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	
	//back to CPU to save theta in the array
	uint8_t *winOut = (uint8_t *) calloc(sqSize * sqSize * 4, sizeof(uint8_t));
	glReadPixels(0, 0, sqSize, sqSize, GL_RGBA, GL_UNSIGNED_BYTE, winOut);
	for (int i=0; i<nb; i++) {
		[[tab objectAtIndex:i] setTheta:winOut[4*i]];
		int j=1;
		while (j<4 && winOut[4*i+j]<100) { //multi-orientation part
			KeyPoint * key = [KeyPoint new];
			[key initParamsX:[[tab objectAtIndex:i] getX] Y:[[tab objectAtIndex:i] getY] Level:[[tab objectAtIndex:i] getLevel]];
			[key setS:[[tab objectAtIndex:i] getS]];
			[key setTheta:winOut[4*i+j]];
			[tab addObject:key];
			j++;
		}
	}
	sqSize=(int)ceil(sqrt((float)[tab count]));
	nb=(int)[tab count];
	
	double tori = [[NSDate date] timeIntervalSince1970] - tori0;
	
    double tdesc0 = [[NSDate date] timeIntervalSince1970];
	
	//description: we store the rotated regions of interest in one single texture
	// and compute their new orientation and weighted magnitude.
	// tiled in 30x30 while only the centered 16x16 are useful to allow 45° rotations.
	glViewport(0, 0, 30*sqSize, 30*sqSize);
	glBindFramebuffer(GL_FRAMEBUFFER, rotBuf);
	glClear(GL_COLOR_BUFFER_BIT);
	glBindTexture(GL_TEXTURE_2D, rotTex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 30*sqSize, 30*sqSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	glBindTexture(GL_TEXTURE_2D, desTex);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 4*sqSize, 4*sqSize, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
	
	for (int i=0; i<nb; i++) {
		KeyPoint* key = [tab objectAtIndex:i];
		int o = [key getLevel]/4;
		int s = [key getLevel]%4;
		int t = [key getT];
		float sig = M_SQRT2*sigma[s];
		float w = (float)(width>>o);
		float h = (float)(height>>o);
		GLfloat x = (float)[key getX]/(float)width;
		GLfloat y = (float)[key getY]/(float)height;
		GLfloat posX = ((float)(i%sqSize)+0.5)/(float)sqSize*2.0-1.0;
		GLfloat posY = ((float)(i/sqSize)+0.5)/(float)sqSize*2.0-1.0;
		GLfloat RotPos [] = { //had to adjustate so there is the right number of pixels:
			posX+1.01*cos(-(3+t)*M_PI_4)/(float)sqSize, posY+sin(-(3+t)*M_PI_4)/(float)sqSize,
			posX+1.01*cos(-(1+t)*M_PI_4)/(float)sqSize, posY+sin(-(1+t)*M_PI_4)/(float)sqSize,
			posX+1.01*cos((3-t)*M_PI_4)/(float)sqSize, posY+sin((3-t)*M_PI_4)/(float)sqSize,
			posX+1.01*cos((1-t)*M_PI_4)/(float)sqSize, posY+sin((1-t)*M_PI_4)/(float)sqSize,
		};
		glUseProgram(orientation);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, gxTex[o]);
		glUniform1i(orientationPicGradx, 0);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, gyTex[o]);
		glUniform1i(orientationPicGrady, 1);
		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, gauss2);
		glUniform1i(orientationPicGauss, 2);
		glActiveTexture(GL_TEXTURE0);
		glUniform1i(orientationScale, s);
		glUniform1i(orientationTheta, t);
		GLfloat regCoord[] = 
		{
			x-(8.0*sig)/(float)w, y-(8.0*sig)/(float)h,
			x+(8.0*sig)/(float)w, y-(8.0*sig)/(float)h,
			x-(8.0*sig)/(float)w, y+(8.0*sig)/(float)h,
			x+(8.0*sig)/(float)w, y+(8.0*sig)/(float)h,
		};
		glVertexAttribPointer(orientationReadingPosition0, 2, GL_FLOAT, GL_FALSE, 0, regCoord);
		glVertexAttribPointer(orientationWritingPosition, 2, GL_FLOAT, GL_FALSE, 0, RotPos);
		glVertexAttribPointer(orientationReadingPosition1, 2, GL_FLOAT, GL_FALSE, 0, gaussCoord);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	}
	
	
	//finally we compute the descriptor from the previous texture.
	glViewport(0, 0, 4*sqSize, 4*sqSize);
	glUseProgram(descriptor);
	glVertexAttribPointer(descriptorReadingPosition, 2, GL_SHORT, GL_FALSE, 0, readingPosition);
	glVertexAttribPointer(descriptorWritingPosition, 2, GL_SHORT, GL_FALSE, 0, writingPosition);
	glBindTexture(GL_TEXTURE_2D, rotTex);
	glUniform1i(descriptorPic0, 0);
	glUniform1i(descriptorSize, sqSize);
	glBindFramebuffer(GL_FRAMEBUFFER, desBuf);
	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	//readback descriptor to CPU
	uint8_t *desOut = (uint8_t *) calloc(16.0 * sqSize * sqSize * 4, sizeof(uint8_t));
	uint8_t *reorgOut = (uint8_t *) calloc(32.0 * 4 * nb, sizeof(uint8_t));
	glReadPixels(0, 0, 4*sqSize, 4*sqSize, GL_RGBA, GL_UNSIGNED_BYTE, desOut);
	reorganize(reorgOut, desOut, nb, sqSize);
	normalize(tab, reorgOut, nb);
	
    double tdesc = [[NSDate date] timeIntervalSince1970]- tdesc0;
	
	/*
	//writing to text file
	NSMutableString *desString = [NSMutableString stringWithCapacity:0];
	NSMutableString *frameString = [NSMutableString stringWithCapacity:0];
	for (int i=0; i<[tab count]; i++) {
		KeyPoint *key=[tab objectAtIndex:i];
		[frameString appendString:[NSString stringWithFormat:@"%u\t%u\t%1.3f\t%1.3f\t",[key getX], height-[key getY]-1, [key getS], M_PI-([key getT])*M_PI_4 ]];
		[frameString appendString:@"\n"];
		uint8_t * values = [key getD];
		for (int j=0; j<128; j++) {
			[desString appendString:[NSString stringWithFormat:@"%u ", values[j]]];
		}
		[desString appendString:@"\n"];
	}
	[desString writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/result.des"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	[frameString writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/result.frame"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	// */
	
	//Gives the number of keypoints per scale
	for (int i=0; i<nb; i++) {
		count[[[tab objectAtIndex:i] getLevel]]++;
	}
	NSMutableString * display = [NSMutableString stringWithCapacity:0];
	[display appendString:@"\n"];
	[display appendString:[NSString stringWithFormat:@"Total Keypoints: %u \n",nb]];
	for (int i=0; i<16
		 ; i++) {
		[display appendString:[NSString stringWithFormat:@"Level %u : %u \n",i,count[i]]];
	}
	NSLog(display,nil);
	

	NSTimeInterval total = [[NSDate date] timeIntervalSince1970]-tinit;

	NSString *result = [NSString stringWithFormat:@"Done in %1.3f s \nDetection: %1.3f s\nOrientation: %1.3f s\nDescription: %1.3f s\n",total, tdetect, tori, tdesc];
    
    NSLog(@"%@", result);
    /*/
	[[[UIAlertView alloc] initWithTitle:@"Results"
                                 message:result
                                delegate:nil
                       cancelButtonTitle:@"OK"
                       otherButtonTitles:nil] show];
    //*/
	
	return tab;
}


// Release resources when they are no longer needed.
- (void)dealloc
{
	if([EAGLContext currentContext] == context) {
		[EAGLContext setCurrentContext:nil];
	}
	
	context = nil;
}

@end
