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
	
	int nb_of_people <- 1000;
	float min_perception_distance <- 50.0;
	float max_perception_distance <- 500.0;
	

	init {
		create hazard;
		create inhabitant number:nb_of_people;
	}
		
}

species hazard {
	
	float speed <- 0.2#km/#h;
	
	geometry shape <- circle(20#m);
	 
	reflex expand {
		shape <- shape buffer (speed * step);
	} 
	
}

species inhabitant {

	float perception_dist <- rnd(min_perception_distance, max_perception_distance);
	bool alerted <- false;

	reflex perceive_hazard when: not alerted {
		alerted <- not empty (hazard at_distance perception_dist);
	}
		
	aspect default {
		draw circle(1#m) color: alerted ? #red :#blue;
	}

}

experiment my_experiment {
	output {
		display my_display type: opengl { 
			species hazard;
			species inhabitant;
		}
	}
}

