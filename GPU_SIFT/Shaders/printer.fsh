//fragment shader
//simply displays an image

varying mediump vec2 tCoord;
uniform lowp sampler2D pic;
void main(void)
{
	//gl_FragColor=texture2D(Image, tCoord);
	gl_FragColor=vec4(texture2D(pic,tCoord).w);
}