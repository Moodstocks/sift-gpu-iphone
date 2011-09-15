//fragment shader that computes a [-1 0 1] gradient

varying mediump vec2 tCoord;
uniform lowp sampler2D pic0;
uniform lowp sampler2D pic1;
uniform mediump float sigma[4];
uniform mediump vec2 dir;
void main(void)
{
	lowp vec4 ur = vec4(texture2D(pic0, tCoord + sigma[0]*dir).y, texture2D(pic0, tCoord + sigma[1]*dir).z, texture2D(pic1, tCoord + sigma[2]*dir).x, texture2D(pic1, tCoord + sigma[3]*dir).y);
	lowp vec4 dl = vec4(texture2D(pic0, tCoord - sigma[0]*dir).y, texture2D(pic0, tCoord - sigma[1]*dir).z, texture2D(pic1, tCoord - sigma[2]*dir).x, texture2D(pic1, tCoord - sigma[3]*dir).y);
	gl_FragColor = (ur-dl+1.0)/2.0;
	
}