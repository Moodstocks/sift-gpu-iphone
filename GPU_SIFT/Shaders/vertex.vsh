//vertex shader
//for applications using the same writing and reading coordinates

attribute lowp vec4 writingPosition;
attribute mediump vec2 readingPosition; 
varying mediump vec2 tCoord;
void main(void)
{
	gl_Position = writingPosition;
	tCoord=readingPosition;
}							 
