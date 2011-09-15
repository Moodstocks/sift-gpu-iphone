//fragment shader
//computes vertical or horizontal gradient

varying mediump vec2 tCoord;
uniform lowp sampler2D pic0;
uniform lowp sampler2D pic1;
uniform mediump float sigma[4];
uniform mediump vec2 direction;
void main(void)
{
	lowp vec4 ur = vec4(texture2D(pic0, tCoord + sigma[0]*direction).y, texture2D(pic0, tCoord + sigma[1]*direction).z, texture2D(pic1, tCoord + sigma[2]*direction).x, texture2D(pic1, tCoord + sigma[3]*direction).y);
	lowp vec4 dl = vec4(texture2D(pic0, tCoord - sigma[0]*direction).y, texture2D(pic0, tCoord - sigma[1]*direction).z, texture2D(pic1, tCoord - sigma[2]*direction).x, texture2D(pic1, tCoord - sigma[3]*direction).y);
	gl_FragColor = (ur-dl+1.0)/2.0;
	
}