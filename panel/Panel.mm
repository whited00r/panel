#import <Preferences/Preferences.h>

@interface PanelListController: PSListController {
}
-(NSArray*)panelNames:(id)target;
-(NSArray*)panelValues:(id)target;
@end


#define debug TRUE
@implementation PanelListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"Panel" target:self] retain];
	}
	return _specifiers;
}



-(NSArray*)panelNames:(id)target{
//Create the initial array to return
NSMutableArray *namesArray = [NSMutableArray array];
	if(debug) NSLog(@"PanelSettings: Running through directories for panel to check for panels");
//Loop through the bundle
for(NSString *pBundle in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Panel/Panels/" error:nil]){
	//Check if the bundle has an info.plist, if not, probably shouldn't load it up.

	if(debug) NSLog(@"PanelSettings: Checking %@", pBundle);
	if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Library/Panel/Panels/%@/Info.plist", pBundle]]){
		//It has it, grab the info.plist!
		NSDictionary *info = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"/Library/Panel/Panels/%@/Info.plist", pBundle]];

		//Determine if it has a CFBundleDisplayName, and if so, use that, otherwise use the folder bundle name without the .bundle extension.
		if([info valueForKey:@"CFBundleDisplayName"]){
			[namesArray addObject:[[info valueForKey:@"CFBundleDisplayName"] copy]];
			NSLog(@"LibLSDebug-Settings: Loading up: %@", [info valueForKey:@"CFBundleDisplayName"]);
		}
		else{
			if(debug) NSLog(@"PanelSettings: No Info.plist found in %@", pBundle);
			[namesArray addObject:[pBundle stringByReplacingOccurrencesOfString:@".bundle" withString:@""]];
		}
		[info release];
	}
	else{
		if(debug) NSLog(@"PanelSettings: Not adding %@ with path /Library/Panel/Panels/%@/Info.plist", pBundle, pBundle);
	}
}


return namesArray;
}

-(NSArray*)panelValues:(id)target{

//Create the initial array to return
NSMutableArray *valuesArray = [NSMutableArray array];

//Loop through the bundle
for(NSString *pBundle in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/Library/Panel/Panels/" error:nil]){
	//Check if the bundle has an info.plist, if not, probably shouldn't load it up.
	if(debug) NSLog(@"PanelSettings: lockScreenValues: %@", pBundle);
	if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"/Library/Panel/Panels/%@/Info.plist", pBundle]]){
		if(debug) NSLog(@"PanelSettings: Adding %@", pBundle);
		[valuesArray addObject:pBundle];

	}
	else{
		if(debug) NSLog(@"PanelSettings: Not Adding %@ with path /Library/Panel/Panels/%@/Info.plist", pBundle, pBundle);
	}
}

return valuesArray;
}
@end

// vim:ft=objc
