//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// Name: 	PreprocessTimeLapse_batch ImageJ macro
//// Author:	Sébastien Tosi (IRB / Barcelona)
//// Version:	1.0
////
//// Aim: 	Apply incremental user defined fixed X and Y shift to every Z slices of a 3D time-lapse to compensate overall directed movement.
////
//// Usage:	- Open original movie hyperstack (drag and drop TIFF file to Fiji bar)
////		- Launch macro
////		- Input offsets to apply (pixels/frame in both directions)
////		- Press OK
////
//// Note:	Macro tested with Fiji Lifeline June 2014 under Windows 7
////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Dialog box
Dialog.create("Apply linear XY shift");
Dialog.addNumber("X shift (pix/frame)", -10);
Dialog.addNumber("Y shift (pix/frame)", 0);
Dialog.show();
XShift = Dialog.getNumber();
YShift	= Dialog.getNumber();

// Batch mode
setBatchMode(true);

// Duplicate image
NewName = "Corrected_X"+d2s(XShift,0)+"_Y"+d2s(YShift,0)+"_"+getTitle();
run("Duplicate...", "title=["+NewName+"] duplicate");

// Shift images
Stack.getDimensions(width, height, channels, slices, frames);
for(f=0;f<frames;f++)
{
	for(z=1;z<=slices;z++)
	{
		Stack.setPosition(1, z, f+1);
		run("Translate...", "x="+d2s(XShift*f,0)+" y="+d2s(YShift*f,0)+" interpolation=None slice");
	}
}

// Reset display
Stack.setPosition(1,1,1);
setBatchMode("exit & display");