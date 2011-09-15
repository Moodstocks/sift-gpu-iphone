//fragment shader
//Computes the descriptor
varying mediump vec2 tCoord;
uniform lowp sampler2D pic0;
uniform int sqSize;
void main(void)
{
	mediump float off = 1.0/(30.0*float(sqSize));
	//we transform the coordinates
	mediump vec2 case = floor(float(sqSize)*tCoord);
	mediump vec2 sub = floor(fract(float(sqSize)*tCoord)*4.0);
	mediump vec2 coord=case/float(sqSize)+7.01*off+4.0*sub*0.99*off;
	//we gather values
	mediump float bins[8];
	for (int i=0; i<8; i++) {
		bins[i]=0.0;
	}
	for (int i=0; i<4; i++) {
		mediump float h = float(i==1 || i==2);
		for (int j=0; j<4; j++) {
			h += float(i==1 || i==2);
			mediump vec4 c=texture2D(pic0,coord+vec2(float(i)*off,float(j)*off));
			mediump float d=fract(c.x*8.0);
			bins[int(floor(c.x*8.0))]+=(1.0-d)*c.y*(0.6+0.2*h)/64.0;
			bins[int(mod(floor(c.x*8.0+1.0),8.0))]+=d*c.y*(0.6+0.2*h)/64.0;
		}
	}
	//descriptors, with 4 bits per bin only...
	gl_FragColor=vec4(16.0*bins[0]+bins[1], 16.0*bins[2]+bins[3], 16.0*bins[4]+bins[5], 16.0*bins[6]+bins[7]);
}