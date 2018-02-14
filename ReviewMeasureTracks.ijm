//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////
//// Name: 	ReviewMeasureTracks_multiBBs ImageJ macro
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

// Force IJ to a predictable state
roiManager("Associate", "false");
run("Line Width...", "line=2");
run("Remove Overlay");
run("Select None");
Stack.setPosition(1, 1, 1);

// Retrieve calibration and image dimensions
Stack.getUnits(Xunit, Yunit, Zunit, Tunit, Value);
Stack.getDimensions(width, height, channels, slices, frames);
getVoxelSize(vxw, vxh, vxd, unit);
TimeStep = Stack.getFrameInterval();

// Initialize windows
if(isOpen("ROI Manager"))
{
	selectWindow("ROI Manager");
	run("Close");
}
if(!isOpen("Tracks Statistics"))
{
	run("Table...", "name=[Tracks Statistics] width=400 height=300 menu");
	print("[Tracks Statistics]", "\\Headings: Track ID \t Length ("+Xunit+") \t Total Disp ("+Xunit+") \t Mean speed ("+Xunit+"/"+Tunit+") \t Persistence");
}

// Initialize variables
Colors = newArray("red","green","blue","magenta","cyan");
CurrentTrackID = getResult("TRACK_ID",0); 					// Index of track currently analyzed --> init to first row
StartRow = 0;									// Starting row of the current track
CurrentTrkLgth = 0;								// Current track length
CntTrk = 0;									// Total number of tracks starting in user defined bounding box
CntSelTrk = 0;									// Total number of tracks validated by the user
ROIManagerTrkIndx = newArray(9999); 						// Starting index of tracks in ROI Manager
ROIManagerTrkID = newArray(9999); 						// ID of tracks in ROI Manager
if(getResult("TRACK_ID",nResults-1)!=9999)setResult("TRACK_ID",nResults,9999);  // This is to make sure that the last track is also processed!
updateResults();

// Dialog box
Dialog.create("Trackmate_ProcessTrack");
Dialog.addNumber("X shift correction factor (pix/frame)", -10);
Dialog.addNumber("Y shift correction factor (pix/frame)", 0);
Dialog.addCheckbox("Manual check?", true);
Dialog.show();
ShiftX = Dialog.getNumber();
ShiftY = Dialog.getNumber();
ManualCheck = Dialog.getCheckbox();

// User defined track start bounding box
setTool("rectangle");
waitForUser("Add starting bounding boxes to Manager with 't'");
NBBs = 0;
if(roiManager("count")==0)
{
	run("Select All");
	roiManager("Add");
}
NBBs = roiManager("count");
Bx = newArray(NBBs);
By = newArray(NBBs);
Bwidth = newArray(NBBs);
Bheight = newArray(NBBs);
for(i=0;i<NBBs;i++)
{
	roiManager("select",i);
	getSelectionBounds(Bx[i], By[i], Bwidth[i], Bheight[i]);
}
if(isOpen("ROI Manager"))
{
	selectWindow("ROI Manager");
	run("Close");
}

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
		Array.sort(TPos);

		// Only process track if first position starts at time frame 0
		if(TPos[0]==0)
		{
		
		// Fill position arrays (re-order time points + correct motion)
		XPos = newArray(CurrentTrkLgth);
		YPos = newArray(CurrentTrkLgth);
		ZPos = newArray(CurrentTrkLgth);
		for(j=0;j<CurrentTrkLgth;j++)
		{
			XPos[j] = getResult("POSITION_X",StartRow+IndxTPos[j])-ShiftX*getResult("FRAME",StartRow+IndxTPos[j])*vxw;
			YPos[j] = getResult("POSITION_Y",StartRow+IndxTPos[j])-ShiftY*getResult("FRAME",StartRow+IndxTPos[j])*vxh;
			ZPos[j] = getResult("POSITION_Z",StartRow+IndxTPos[j]);
		}
		
		// Only process track if first position inside starting box
		Test = 0;
		for(t=0;t<NBBs;t++)Test = Test + ((((XPos[0])>=Bx[t]*vxw)&&((XPos[0])<=(Bx[t]+Bwidth[t])*vxw)&&((YPos[0])>=By[t]*vxh)&&((YPos[0])<=(By[t]+Bheight[t])*vxh))>0);
		if(Test>0)
		{
			CntTrk++; 	// Update track counter
			CntSelTrk++; 	// For now we consider that the track will be selected

			// Draw track (XY)
			XPosPix = newArray(CurrentTrkLgth);
			YPosPix = newArray(CurrentTrkLgth);
			for(j=0;j<CurrentTrkLgth;j++)
			{
				XPosPix[j] = round(XPos[j]/vxw);
				YPosPix[j] = round(YPos[j]/vxh);
			}
			makeSelection("polyline", XPosPix, YPosPix);

			// Add track XY plot to ROI manager (in start slice)
			Stack.setPosition(1, 1+round(ZPos[0]/vxd), 1+TPos[0]);
			roiManager("add");
			
			// Rename ROI (track name)
			roiManager("select",roiManager("count")-1);
			roiManager("Rename", "Trk_"+IJ.pad(CurrentTrackID,4));
			roiManager("Set Color",Colors[CntSelTrk% lengthOf(Colors)]);
			roiManager("update");
			ROIManagerTrkIndx[CntSelTrk-1] = roiManager("count")-1; 
			ROIManagerTrkID[CntSelTrk-1] = CurrentTrackID;
			
			// Add track points
			for(j=0;j<CurrentTrkLgth;j++)
			{
				Stack.setPosition(1, 1+round(ZPos[j]/vxd), 1+TPos[0]+j);
				makePoint(round(XPos[j]/vxw),round(YPos[j]/vxh));
				roiManager("add");
				roiManager("select",roiManager("count")-1);
				roiManager("Rename", d2s(CntSelTrk,0)+"-"+d2s(j,0));
				roiManager("Set Color",Colors[CntSelTrk% lengthOf(Colors)]);
				roiManager("update");
			}	

			// Manual check
			if(ManualCheck == true)
			{
				roiManager("Show None");
				roiManager("select",ROIManagerTrkIndx[CntSelTrk-1]);
				selectWindow("ROI Manager");
				waitForUser("Inspect current track (select ROI Manager + up/down arrows)");
				keep = getBoolean("Keep track?");
			}
			else keep = true;

			// Track is kept: compute statistics and display to results table 
			if(keep==true)
			{
				Lgth = 0;
				for(j=1;j<CurrentTrkLgth;j++)Lgth = Lgth + sqrt(pow(XPos[j] - XPos[j-1],2)+pow(YPos[j] - YPos[j-1],2)+pow(ZPos[j] - ZPos[j-1],2));
				Disp = sqrt(pow(XPos[CurrentTrkLgth-1] - XPos[0],2)+pow(YPos[CurrentTrkLgth-1] - YPos[0],2)+pow(ZPos[CurrentTrkLgth-1] - ZPos[0],2));
				MeanSpeed = Lgth/(TimeStep*(CurrentTrkLgth-1));
				Persistence = Disp/Lgth;
				print("[Tracks Statistics]", d2s(CurrentTrackID,0)+"\t"+d2s(Lgth,2)+"\t"+d2s(Disp,2)+"\t"+d2s(MeanSpeed,4)+"\t"+d2s(Persistence,2));
			}
			else 
			{
				// Track is discarded, remove it from ROI manager
				for(j=roiManager("count")-1;j>=ROIManagerTrkIndx[CntSelTrk-1];j--)
				{
					roiManager("select",j);
					roiManager("delete");
				}
				// Update selected tracks counter
				CntSelTrk--;
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