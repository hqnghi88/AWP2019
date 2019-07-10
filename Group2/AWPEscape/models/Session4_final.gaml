/***
* Name: AWPEscape
* Author: AWP
* Description: Step 0 of the AWP training evacuation model 
* Tags: evacuation and flood
***/
model CityEscape

global {
	
	file road_file <- file("../includes/road_environment.shp");
	file buildings <- file("../includes/building_environment.shp");
	file evac_points <- file("../includes/evacuation_environment.shp");
	file water_body <- file("../includes/sea_environment.shp");
	
	geometry shape <- envelope(envelope(road_file)+envelope(water_body));
	
	graph<geometry, geometry> road_network;
	
	float step <- 10#s;

	int nb_of_people <- 1000;
	float min_perception_distance <- 50.0;
	float max_perception_distance <- 500.0;
	
	int casualties;

	init {
		create road from:road_file;
		create building from:buildings;
		
		create hazard from:water_body;
		create evacuation_point from:evac_points;
		
		create inhabitant number:nb_of_people {
			location <- any_location_in(one_of(building));
		}
		
		road_network <- as_edge_graph(road);
	}
	
	reflex stop_simu when:empty(inhabitant){
		do pause;
	}
		
}

species hazard {
	
	float speed <- 0.2#km/#h;
	 
	reflex expand {
		shape <- shape buffer (speed * step);
		ask inhabitant overlapping self {
			casualties <- casualties + 1; 
			do die;
		}
	}
	
	aspect default {
		draw shape color:#blue;
	}
	
}

species inhabitant skills:[moving] {

	evacuation_point safety_point <- evacuation_point closest_to self;

	float perception_dist <- rnd(min_perception_distance, max_perception_distance);
	bool alerted <- false;

	reflex perceive_hazard when: not alerted {
		alerted <- not empty (hazard at_distance perception_dist);
	}
	
	reflex evacuate when: alerted {
		do goto target:safety_point on:road_network;
		if(location distance_to safety_point.location < 2#m){ 
			ask safety_point {do evacue_inhabitant;}
			do die;
		}
	}
	
	aspect default {
		draw circle(1#m) color: alerted ? #red : #blue;
	}

}

species road {
	aspect default {
		draw shape color: #black;
	}
}

species building {
	aspect default {
		draw shape color: #gray border: #black;
	}
}

species evacuation_point {
	
	int count_exit <- 0;
	
	action evacue_inhabitant {
		count_exit <- count_exit + 1;
	}

	aspect default {
		draw circle(1#m+19#m*count_exit/nb_of_people) color:#green;
	}	
}

experiment my_experiment {
	output {
		display my_display type: opengl { 
			species hazard;
			species road;
			species inhabitant;
			species building;
			species evacuation_point;
		}
		monitor number_of_casualties value:casualties;
	}
}

