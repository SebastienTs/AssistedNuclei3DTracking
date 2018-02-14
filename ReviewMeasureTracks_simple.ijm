//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// Name: 	ReviewMeasureTracks_simple ImageJ macro
//// Author:	Sébastien Tosi (IRB / Barcelona)
//// Version:	1.0
////
//// Aim: 	Import Trackmate tracks, select track subset from spatial / temporal starting position, visualize track, validate track,
////		compute cinematics measurements (mean speed and directional persistence) and store them to exportable results table.
////
//// Usage:	- Open original movie hyperstack (drag and drop TIFF file to Fiji bar)
////		- Import Trackmate results table "Spots in tracks statistics" (drag and drop to Fiji bar)
////		- Launch macro
////		- Set directed movement compensation shift / fame as applied prior to tracking
////		- Draw track starting bounding box in FIRST TIME FRAME
////		- Sequentially review and validate tracks by following instructions
////		- Export cinematic measurements form results table menu
////
//// Note:	Macro tested with Fiji Lifeline June 2014 under Windows 7
////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Retrieve calibration and image dimensions
Stack.getUnits(Xunit, Yunit, Zunit, Tunit, Value);
Stack.getDimensions(width, height, channels, slices, frames);
getVoxelSize(vxw, vxh, vxd, unit);
TimeStep = Stack.getFrameInterval();

// Initialize windows
if(!isOpen("Tracks Statistics"))
{
	run("Table...", "name=[Tracks Statistics] width=400 height=300 menu");
	print("[Tracks Statistics]", "\\Headings: Track ID \t Length ("+Xunit+") \t Total Disp ("+Xunit+") \t Mean speed ("+Xunit+"/"+Tunit+") \t Persistence");
}

// Initialize variables
CurrentTrackID = getResult("TRACK_ID",0); 					// Index of track currently analyzed --> init to first row
StartRow = 0;									// Starting row of the current track
CurrentTrkLgth = 0;								// Current track length
CntTrk = 0;									// Total number of tracks starting in user defined bounding box
CntSelTrk = 0;									// Total number of tracks validated by the user
if(getResult("TRACK_ID",nResults-1)!=9999)setResult("TRACK_ID",nResults,9999);  // This is to make sure that the last track is also processed!
updateResults();

// Dialog box
Dialog.create("Trackmate_ProcessTrack");
Dialog.addNumber("X shift correction factor (pix/frame)", -10);
Dialog.addNumber("Y shift correction factor (pix/frame)", 0);
Dialog.show();
ShiftX = Dialog.getNumber();
ShiftY = Dialog.getNumber();

// User defined track start bounding box
setTool("rectangle");
waitForUser("Draw a bounding box to locate track starting positions");
getSelectionBounds(Bx, By, Bwidth, Bheight);

// Analyze tracks by sequentially reading track IDs
for(i=0;i<nResults;i++)
{
	TrkID = getResult("TRACK_ID",i);
	
	// THE TRICK: Wander all results line one by one, a new track is detected when TRACK_ID changes
	if(TrkID != CurrentTrackID)
	{
		// Re-order track position by ascending time frames
		TPos = newArray(CurrentTrkLgth);	
		for(j=0;j<CurrentTrkLgth;j++)TPos[j] = getResult("FRAME",StartRow+j);
		IndxTPos = Array.rankPositions(TPos);

		// Only process track if first position starts at first time frame
		if(TPos[IndxTPos[0]]==0)
		{
			
		// Fill position arrays (re-order time points + correct motion)
		TPos = newArray(CurrentTrkLgth);
		XPos = newArray(CurrentTrkLgth);
		YPos = newArray(CurrentTrkLgth);
		ZPos = newArray(CurrentTrkLgth);
		for(j=0;j<CurrentTrkLgth;j++)
		{
			TPos[j] = getResult("FRAME",StartRow+IndxTPos[j]); 
			XPos[j] = getResult("POSITION_X",StartRow+IndxTPos[j])-ShiftX*TPos[j]*vxw;
			YPos[j] = getResult("POSITION_Y",StartRow+IndxTPos[j])-ShiftY*TPos[j]*vxh;
			ZPos[j] = getResult("POSITION_Z",StartRow+IndxTPos[j]);
		}
		
		// Only process track if first position inside starting box
		if(((XPos[0])>=Bx*vxw)&&((XPos[0])<=(Bx+Bwidth)*vxw))
		{
		if(((YPos[0])>=By*vxh)&&((YPos[0])<=(By+Bheight)*vxh))
		{
			CntTrk++; 	// Update track counter
			CntSelTrk++; 	// For now we consider that the track will be selected

			// Close ROI Manager if opened
			if(isOpen("ROI Manager"))
			{
				selectWindow("ROI Manager");
				run("Close");
			}
		
			// Add track points
			for(j=0;j<CurrentTrkLgth;j++)
			{
				Stack.setPosition(1, 1+round(ZPos[j]/vxd), 1+TPos[0]+j);
				makePoint(round(XPos[j]/vxw),round(YPos[j]/vxh));
				roiManager("add");
			}	

			// Manual check
			roiManager("Show None");
			roiManager("select",0);
			selectWindow("ROI Manager");
			waitForUser("Inspect current track (select ROI Manager + up/down arrows)");
			
			// Track is kept: compute statistics and display to results table 
			keep = getBoolean("Keep track?");
			if(keep==true)
			{
				Lgth = 0;
				for(j=1;j<CurrentTrkLgth;j++)
				{
					Lgth = Lgth + sqrt(pow(XPos[j] - XPos[j-1],2)+pow(YPos[j] - YPos[j-1],2)+pow(ZPos[j] - ZPos[j-1],2));
				}
				Disp = sqrt(pow(XPos[CurrentTrkLgth-1] - XPos[0],2)+pow(YPos[CurrentTrkLgth-1] - YPos[0],2)+pow(ZPos[CurrentTrkLgth-1] - ZPos[0],2));
				MeanSpeed = Lgth/(TimeStep*(CurrentTrkLgth-1));
				Persistence = Disp/Lgth;
				print("[Tracks Statistics]", d2s(CurrentTrackID,0)+"\t"+d2s(Lgth,2)+"\t"+d2s(Disp,2)+"\t"+d2s(MeanSpeed,4)+"\t"+d2s(Persistence,2));
			}
			
		}
		}
		}
		
		// Starting results table row for next track
		StartRow = i;
		CurrentTrkLgth = 0;
		CurrentTrackID = TrkID;
	}
	CurrentTrkLgth++;
}

// Display information
print("Selected tracks: "+d2s(CntSelTrk,0)+" out of "+d2s(CntTrk,0)+" starting in user defined location");
roiManager("Show All without labels");