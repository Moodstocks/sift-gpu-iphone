//vertex shader
//non reading coordinates, made to works on each pixel individually

attribute highp vec4 writingPosition;
void main(void)
{
	gl_Position = writingPosition;
}							 
