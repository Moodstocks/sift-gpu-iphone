# Moodstocks SIFT on iPhone GPU

## Foreword

In this project we implemented [Lowe's SIFT algorithm](http://www.cs.ubc.ca/~lowe/papers/ijcv04.pdf) (pdf), using the GPU of the iPhone whenever it was possible. As the different generations of iPhone still don't allow the use of GPGPU-oriented languages such as Cuda or OpenCL, this project uses OpenGL and its shading language, GLSL.

## How to use

It's quite simple.

* Init ??
* Once your `SIFT` object is created, initialize it to the dimensions of the images you want to process, and specify the number of octaves you want to compute. For example: `[mySIFT initWithWidth:360 Height:480 Octaves:4];` . Once the object is initialized, it can be used as many times as you want.
* Convert the picture you want to process to a `CGImageRef`.
* Send it to your `SIFT` object: `[mySIFT computeSIFT:myCGImage]`. It will return an `NSMutableArray<KeyPoint>` containing all your SIFT points. 
	
These KeyPoints objects are provided with 4 usefull methods:
* `-(int) getX` and `-(int) getY` that will give you the position of the SIFT point in pixels from the top left corner.
* `-(float) getS` provides the value of sigma corresponding to its scale
* `-(uint8_t*) getD` returns the descriptor

## Implementation Detail

It is important to remember that, as we work in OpenGL, every step of the algorithm that we compute on the GPU will have to work with RGBA textures in input and output, with the advantages and inconvenients that it supposes. If working with images allows a very visual developping and validation process, it also requires that we work on a limited 4 x 8 bits per pixel, which sometimes caused precision problems.

In this whole project, we used a trick to exploit the standard format of RGBA textures used by the GPU to our advantage: we use each one of the R, G, B and A channels of our images to store a different level of gaussian pyramid. This way, we always process 4 images at a time, thus reducing computation time. In this first step, we have fixed the number of scale levels per octave to 4, to get the maximum of this trick.

### Detection part

Our objective being to have 4 levels of key points per octave at the end of the detection process, we need to compute 7 levels of gaussian smoothing for each octave: these 7 levels will allow us to produce 6 levels of difference of gaussians, which will allow us to perform a non-maxima suppression on the 4 middle ones without suffering any border effect.

Gaussian smoothing is thus performed in 2 textures holding these 7 levels, using a gaussian kernel of size 2 x 14 + 1. This size was determined by the necessity to have wide enough kernels when computing the level with the higher sigma. We use the separability of the 2-D gaussian smoothing to perform it in 2 passes, a 1-D horizontal smoothing followed by a vertical one.
As computing a 29 elements convolution in OpenGL is extremely slow, we chose to process each 1-D gaussian convolution in 2 passes, one computing the first half-gaussian, the second one summing this result with the second half gaussian. 

A simple difference is then computed between adjacent scales of gaussian smoothing to get our 6 DoG levels. This is were we suffered form the 8-bit output limitation, as it did not allow enough precision for the following non-maxima suppression to work: the result of DoG appeared as noisy, and non-maxima suppression returned an insane number of key points. We thus chose to apply another gaussian smoothing on these DoG levels, to remove this noise and get most of the key points after non-maxima suppression.

We then read back our results to CPU to start filling our results array with the positions and scales of our N key points.

### Description part

In this description part, we will always use the same strategy: now that we have the positions and scales of all our key points and regions of interest, we will at each step create one or several successive S x S mosaic of the keypoints neighbourhoods required to process this step, where S=ceil(sqrt(N)). Let's detail this process:

Our first step is the edge response and low contrast response suppression. In order to compute the contrast and curvatures of the regions of interest, we only need to compute some gradients, which can be done in one single step. We will thus build a SxS texture in which each pixel will be either 0 if kept or 255 if discarded, given the coordinates of its corresponding key point. Once this texture is read back to CPU, points that must be discarded are removed from the array, and N and S are updated.

The next step is to compute the main orientation of each key point. This time we proceed in 2 steps. We begin by building a 16S x 16S picture, each tile containing for each pixel of the region of interest its orientation and gaussian weighted magnitude, encoded in the RGBA channels. Then, from this picture, we build an SxS texture that will, for each pixel, collect the information of the previous texture and deduce the main orientation from it. In this step, we chose to quantize the orientations into 8 main directions.

The final step is description. In order to do this, we begin by building a 30Sx30S texture, in which each 30x30 tile will contain the corresponding region of interest, rotated so that its main orientation is upright. For each pixel of this region of interest, we compute the orientation and weighted magnitude. Once this is done, we build another 4Sx4S texture that collects information from the previous one, and store for each 4x4 tile the values needed to build the descriptor, once more encoded in the RGBA channels. In this step, as we are still limited to 8 bits per component and must store 8 values per pixel, we decided that 4 bits per value would be enough, in order to avoid having to make 2 passes.

Finally these results are read back to CPU, where they can be stored in the array.
