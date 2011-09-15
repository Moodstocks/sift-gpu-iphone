//fragment shader
//computes horizontal or vertical smoothing, in 2 passes.
varying mediump vec2 tCoord;
uniform mediump sampler2D pic0;
uniform mediump sampler2D pic1;
uniform mediump vec4 gaussianCoeff[15];
uniform mediump vec2 direction;
void main(void)
{
	mediump vec4 r = gaussianCoeff[0]*texture2D(pic0, tCoord);
	for (int i=1; i<8; i++) {
		r+=gaussianCoeff[i]*texture2D(pic1, tCoord+float(i)*direction);
		r+=gaussianCoeff[i+7]*texture2D(pic1, tCoord+float(i+7)*direction);
		
	}
	gl_FragColor = r;

}
