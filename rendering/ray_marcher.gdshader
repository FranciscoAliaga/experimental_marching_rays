shader_type canvas_item;

#include "./ray_marching.gdshaderinc"

// x horizontal
// y vertical
// z forward

/* parameters pulled from godot scene */
uniform vec3 camera_pos;
uniform mat3 camera_rotation;


/* parameters pulled from texture material */
uniform int x_pixels;
uniform int y_pixels;

uniform float max_reflection : hint_range(0.,1.);

uniform vec4 floor_color : source_color;
uniform vec4 sky_color : source_color;
uniform vec4 fog_color : source_color;
uniform float foggyness : hint_range(0.,1.);
uniform float fog_decay : hint_range(1.,100.);

// constants //

// for calculating derivatives
const float dh   = 0.01;
const float idh  = 1./dh;

// to assess if ray stopped near or far objects.
const float near = 0.01;
const float far  = 100.;

// algorithm parameters. Tweak these!
#define RAY_BOUNCES 3 // more -> more reflections. Needs to be at least 1. Less is faster.
#define JUMP_SEARCH 3 // bounce performance is improved with more. Less is faster.
#define JUMP_MULT 20. // bounce performance is improved if less (but step up jump search)

#define MAX_STEPS 50 // Maximum ray marching steps for each ray. less is faster, and near 10 it's quite aesthetical

// takes an uv coordinate from the screen renderer and
// returns the normalized ray.
vec3 ray(vec2 uv){
	// center uv
	vec2 uuvv = uv - vec2(0.5,0.5);
	// invert y coordinate
	uuvv.y *= -1.;
	// pass a ray through the {(x,y,z) : z=1} plane coming from the origin
	vec3 rd = vec3(uuvv,1.);
	// transform it according to camera
	rd = camera_rotation * rd;
	// return answer
	return normalize(rd);
}

/* Most important function */
// returns the Signed Distance Function; 
// each "object" is "declared" here. Reading SDFs is recommended prior to tweaking this.
// gets called several times from the ray marching algorithm
float get_sdf(vec3 pos, float t){
	// put a sphere at the center
	vec3 center = vec3(0.,-2.,5.);
	float sdf = sphere_sdf(pos,center,1.);
	
	// put several bodies on a ring
	float r = 4.; // ring radius
	float RR = 0.7; // body radius
	int N = 10; // Number of figures
	for(int i = 0; i <N ; i++ ){
		float angle = 2.*PI*float(i)/float(N); // spinning,
		vec3 c_center = center + vec3(0.,0.,0.); // centered at
		vec3 displacement = r*vec3(cos(angle+t),0.,sin(angle+t));
		// even numbers yield spheres, odd, cubes
		if (i%2==0){
			sdf = min(sdf,sphere_sdf(pos,c_center+displacement,RR));
		}
		else{
			sdf = min(sdf,cube_sdf(pos,c_center+displacement,vec3(RR)));
		}
	}
	return sdf;
}

// Gradient of the SDF. Used for calculating normals (therefore bounces)
vec3 get_gradient(vec3 pos,float t){
	float dx = get_sdf(pos+vec3(dh,0.,0.),t) - get_sdf(pos,t) ;
	float dy = get_sdf(pos+vec3(0.,dh,0.),t) - get_sdf(pos,t) ;
	float dz = get_sdf(pos+vec3(0.,0.,dh),t) - get_sdf(pos,t) ;
	return vec3(dx,dy,dz)*idh;
}

// used to fetch colors.
// faraway stuff (given by high depth) gets background colors
// (sdf <= 1.5 near) represents solid objects
// everything else is just black.
// absolutely tweak this.
vec4 get_color(vec3 pos,float depth, float t){
	if (depth >= far){
		if (pos.y > 0.) return sky_color;
		else return floor_color;
	}
	if (get_sdf(pos,t)<=1.5*near){
		return vec4(1.,0.,0.,1.);
	}
	return vec4(vec3(1.),0.);
}

/* A single Ray */

ray_march_hit ray_march(vec3 pos, vec3 ray, float t, bool first_ray){
	ray_march_hit result;
	result.depth = 0.;
	
	bool break_condition = false;
	int steps = 0;
	float d;
	
	if(first_ray){ // ray coming from camera
		d = get_sdf(pos,t);
	} else { // ray bouncing out of a surface, the ray needs help getting out of the object:
		 // find largest d such that gradient is increasing with ray.
		d = near;
		for(int j = 0; j<JUMP_SEARCH;j++){
			vec3 gradient = get_gradient(pos+d*ray ,t);
			bool getting_away = dot(ray,normalize(gradient)) > 0.;
			if (!getting_away){
				d /= JUMP_MULT;
				break;
			}
			d*= JUMP_MULT;
		}
	}
	
	// ray march
	do {
		result.depth += d;
		pos = pos + ray * d;
		d = get_sdf(pos,t);
		steps++;
		break_condition = (d <= 0.);
	} while ( (!break_condition) && (steps < MAX_STEPS  ));
	
	result.position = pos;
	result.color  = get_color(pos,result.depth,t);
	return result;
}

/*   Algorithm   */

// Generates a ray, then bounces it RAY_BOUNCES times.
// The color is calculated mixing each bound, and the depth is the depth of the first ray.
color_and_depth ray_marching(vec3 pos, vec3 ray, float t){
	color_and_depth result;
	ray_march_hit[RAY_BOUNCES] hits;
	
	for(int i = 0; i < RAY_BOUNCES; i++){
		hits[i] = ray_march(pos,ray,t,(i==0));
		pos = hits[i].position;
		if(length(pos) >= far) continue;
		ray = reflect_vector_plane(ray,get_gradient(pos,t));
	}
	vec4 color = hits[0].color;
	for(int i = 1; i < RAY_BOUNCES; i++){
		color = (1.-max_reflection) * color + max_reflection * hits[i].color;
	}
	
	result.color = color;
	result.depth = hits[0].depth;
	return result;
}

// Shader code. The outgoing camera rays are calculating using camera uniforms (position and rotation)
void fragment() {
	// camera position
	vec3 ro = camera_pos;
	
	// ray angle. 
	//	vec3 rd = ray(UV); // non-pixelation
	 vec3 rd = ray(pixel_uv(UV,ivec2(x_pixels,y_pixels))); // pixeled
	
	// runs algorithm, gets color and depth.
	color_and_depth result = ray_marching(ro,rd,TIME);
	
	// color calculation;
	vec4 color = result.color;
	float ff = foggyness * min(1.,result.depth/fog_decay); // fog is applied depending on depth
	color = (1.-ff) * color + ff * fog_color; 
	
	COLOR = color;
	COLOR.a = 1.;
	
}

