/***
* Name: AWPEscape
* Author: AWP
* Description: Step 0 of the AWP training evacuation model 
* Tags: evacuation and flood
***/
model CityEscape

global {
	
	geometry shape <- 500#m;
	
	float step <- 10#s;

	init {
		create hazard;
	}
		
}

species hazard {
	
	float speed <- 0.2#km/#h;
	
	geometry shape <- circle(20#m);
	 
	reflex expand {
		shape <- shape buffer (speed * step);
	} 
	
}

experiment my_experiment {
	output {
		display my_display type: opengl { 
			species hazard;
		}
	}
}

