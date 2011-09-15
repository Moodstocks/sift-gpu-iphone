//fragment shader
//computes the dominant orientation from orientations and magnitude in the region of interest`
varying mediump vec2 tCoord;
uniform lowp sampler2D pic0;
uniform int sqSize;
void main(void)
{
	mediump vec2 coord=floor(float(sqSize)*tCoord)/float(sqSize);
	mediump float off = 1.0/(16.0*float(sqSize));
	
	mediump float bins[8];
	for (int i=0; i<8; i++) {
		bins[i]=0.0;
	}
	for (int i=0; i<16; i++) {
		for (int j=0; j<16; j++) {
			mediump vec4 c=texture2D(pic0,coord+vec2(float(i)*off,float(j)*off));
			bins[int(mod(floor(c.x*8.0),8.0))]+=c.y;
		}
	}
	
	mediump float best = 0.0;
	int winner=0;
	for (int i=0; i<8; i++) {
		if (bins[i]>best) {
			best=bins[i];
			winner=i;
		}
	}
	//gl_FragColor = vec4(float(winner)/256.0);
	lowp vec4 res = vec4(float(winner)/256.0, 1.0, 1.0, 1.0);
	int j=1;
	for (int i=0; i<8 && j<4; i++) {
		if (i!=winner && bins[i]>0.8*best) {
			res[j]=float(i)/256.0;
			j++;
		}
	}
	gl_FragColor = res;
}