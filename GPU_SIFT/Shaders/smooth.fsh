//fragment shader
//computes horizontal or vertical smoothing, single pass (approximated)
varying mediump vec2 tCoord;
uniform mediump sampler2D pic;
uniform mediump float gaussianCoeff[8];
uniform mediump vec2 direction;
void main(void)
{
	mediump vec4 r = gaussianCoeff[0]*texture2D(pic, tCoord);
	for (int i=1; i<8; i++) {
		r+=gaussianCoeff[i]*texture2D(pic, tCoord+float(i)*direction);
		r+=gaussianCoeff[i]*texture2D(pic, tCoord-float(i)*direction);
	}
	gl_FragColor = r;

}
