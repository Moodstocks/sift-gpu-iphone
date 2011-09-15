//vertex shader
//for applications using 2 different sets of reading Coordinates
attribute mediump vec4 writingPosition;
attribute mediump vec2 readingPositionGrad; 
attribute mediump vec2 readingPositionGauss;
varying mediump vec2 tCoord;
varying mediump vec2 tGauss;
void main(void)
{
	gl_Position = writingPosition;
	tCoord=readingPositionGrad;
	tGauss=readingPositionGauss;
}	