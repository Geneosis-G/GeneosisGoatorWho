class TARDISVehicle extends GGSVehicle
	placeable;

var GoatorWho myMut;
/** The name displayed in a combo */
var string mScoreActorName;

/** The maximum score this longboard is worth interacting with in a combo */
var int mScore;

var float mJumpForceSize;

var GGGoat TARDISOwner;
/*
var TARDISHold mHold;
var GGHUDGfxIngame mHUD;
var bool shouldPopulate;
var float lastSelectedIndex;
*/
var bool isLeaving;
var bool isLanding;
var bool wantTeleport;
var bool wantTimeTravel;
var SoundCue mTARDISLeaveSound;
var SoundCue mTARDISLandSound;

var float mTeleportRange;
var TARDISGhost mGhostTARDIS;
var vector mExpectedLocation;
var bool mShouldBlink;

var int mMapIndex;//Index of the next map this tardis will travel to

simulated event PostBeginPlay()
{
	local int i;

	super.PostBeginPlay();

	mesh.SetHidden(true);

	for( i = 0; i < mNumberOfSeats; i++ )
	{
		// Remove normal seats
		mPassengerSeats[i].VehiclePassengerSeat.ShutDown();
		mPassengerSeats[i].VehiclePassengerSeat.Destroy();
		// Add custom seats
		mPassengerSeats[i].VehiclePassengerSeat = Spawn( class'TARDISSeat' );
		mPassengerSeats[i].VehiclePassengerSeat.SetBase( self );
		mPassengerSeats[i].VehiclePassengerSeat.mVehicleOwner = self;
		mPassengerSeats[i].VehiclePassengerSeat.mVehicleSeatIndex = i;
	}

	InitTARDIS(GGGoat(Owner));
	SetOwner(none);
}

function InitTARDIS(GGGoat TARDIS_owner)
{
	TARDISOwner=TARDIS_owner;

    // Create inventory
    /*mHold = Spawn( class'TARDISHold', self );
	mHold.InitiateInventory();*/

	FindGoatorWho();
	AssignPassengers();
	mMapIndex=myMut.GetRandomMapIndex();

	mExpectedLocation=Location;
}

function FindGoatorWho()
{
	foreach AllActors(class'GoatorWho', myMut)
		break;
}

function AssignPassengers()
{
	local PlayerController PC;
	local GGGoat goat;
	local int tardisID;

	tardisID=myMut.GetTARDISForPassenger(TARDISOwner.mCachedSlotNr);
	if(tardisID != TARDISOwner.mCachedSlotNr)//Only owner can drive, so if he's not driving don't look for passengers
		return;

	TryToDrive(TARDISOwner);

	foreach WorldInfo.AllControllers(class'PlayerController', PC)
	{
		goat=GGGoat(PC.Pawn);
		if(goat == TARDISOwner)
			continue;

		if(goat != none && myMut.GetTARDISForPassenger(goat.mCachedSlotNr) == TARDISOwner.mCachedSlotNr)
		{
			TryToDrive(goat);
		}
	}

	if(bDriving)
	{
		SetHidden(true);
		TARDISLand();
	}
}

simulated event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	if(IsZero(mExpectedLocation))
	{
		mExpectedLocation=Location;
	}

	if(Location != mExpectedLocation)
	{
		Velocity=vect(0, 0, 0);
		SetLocation(mExpectedLocation);
	}

	if(mGhostTARDIS == none || mGhostTARDIS.bPendingDelete)
	{
		mGhostTARDIS=Spawn(class'TARDISGhost');
	}

	/*if(bDriving)
	{
		if(mHUD.mInventoryOpen)
		{
			lastSelectedIndex=mHUD.mInventory.GetFloat( "selectedIndex" );
			//WorldInfo.Game.Broadcast(self, "lastSelectedIndex=" $ lastSelectedIndex);
			if(shouldPopulate)
			{
				PopulateInventory();
			}
		}
	}*/

	UpdateBlockCamera();

	if(!IsTARDISLocked())
	{
		ComputeGhostLocation();
	}

	if(mShouldBlink)
	{
		Blink();
	}

	mGhostTARDIS.SetVisible(bDriving && !IsTARDISLocked());
}

function ComputeGhostLocation()
{
	local vector dest, camLocation;
	local rotator camRotation;
	local vector traceStart, traceEnd, hitLocation, hitNormal, itemExtent;//, itemExtentOffset;
	local Actor hitActor;
	local box itemBoundingBox;
	local float itemExtentCylinderRadius;

	if(Controller != none)
	{
		GGPlayerControllerGame( Controller ).PlayerCamera.GetCameraViewPoint( camLocation, camRotation );
	}
	else
	{
		camLocation=Location;
		camRotation=Rotation;
	}
	traceStart = camLocation;
	traceEnd = traceStart;
	traceEnd += (vect(1, 0, 0)*(mTeleportRange + VSize2D(camLocation-Location))) >> (camRotation + (rot(1, 0, 0)*10*DegToUnrRot));

	mGhostTARDIS.GetComponentsBoundingBox( itemBoundingBox );
	itemExtent = ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f;
	//itemExtentOffset = itemBoundingBox.Min + ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f - mGhostTARDIS.Location;
	itemExtentCylinderRadius = Sqrt( itemExtent.X * itemExtent.X + itemExtent.Y * itemExtent.Y );

	foreach TraceActors( class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart)
	{
		if(hitActor == mGhostTARDIS
		|| hitActor == self
		|| hitActor.Owner == TARDISOwner
		|| VSizeSq(hitLocation-traceStart) < VSizeSq(Location-traceStart)//Too close
		|| Volume(hitActor) != none)
		//|| GGApexDestructibleActor(hitActor) != none)
		{
			continue;
		}

		break;
	}

	if(hitActor == none)
	{
		hitLocation=traceEnd;
	}

	dest = hitLocation - (Normal(traceEnd - traceStart) * itemExtentCylinderRadius);//- itemExtentOffset;

	mGhostTARDIS.SetLocation(dest);
	mGhostTARDIS.SetRotation(rotator(normal2D(traceEnd-traceStart)));
}

function ModifyCameraZoom( PlayerController contr, optional bool exit, optional bool passenger)
{
	local GGCameraModeVehicle orbitalCamera;
	local GGCamera.ECameraMode camMode;

	camMode=passenger?3:2;//Haxx because for some reason calling CM_Vehicle and CM_Vehicle_Passenger no longer works
	orbitalCamera = GGCameraModeVehicle( GGCamera( contr.PlayerCamera ).mCameraModes[ camMode ] );
	//WorldInfo.Game.Broadcast(self, "contr=" $ contr $ ", exit=" $ exit $ ", passenger=" $ passenger $ ", orbitalCamera=" $ orbitalCamera);
	if(exit)
	{
		orbitalCamera.mMaxZoomDistance = orbitalCamera.default.mMaxZoomDistance;
		orbitalCamera.mMinZoomDistance = orbitalCamera.default.mMinZoomDistance;
		orbitalCamera.mDesiredZoomDistance = orbitalCamera.default.mDesiredZoomDistance;
		orbitalCamera.mCurrentZoomDistance = orbitalCamera.default.mCurrentZoomDistance;
	}
	else
	{
		orbitalCamera.mMaxZoomDistance = 6000;
		orbitalCamera.mMinZoomDistance = 1000;
		orbitalCamera.mDesiredZoomDistance = CamDist;
		orbitalCamera.mCurrentZoomDistance = CamDist;
	}
}

function UpdateBlockCamera()
{
	local bool shouldBlockCamera;
	local int i;

	shouldBlockCamera=true;
	if(bDriving)
	{
		shouldBlockCamera=false;
	}
	else
	{
		for( i = 0; i < mPassengerSeats.Length; i++ )
		{
			if( mPassengerSeats[ i ].PassengerPawn != none )
			{
				shouldBlockCamera=false;
				break;
			}
		}
	}
	mBlockCamera=shouldBlockCamera;
}
//Can't enter or leave tardis if teleport in progress
function bool IsTARDISLocked()
{
	return isLeaving || isLanding;
}

/**
 * See super.
 */
function GetInVechile( Pawn userPawn )
{
	super.GetInVechile( userPawn );

}

/**
 * See super.
 *
 * Overridden to register a key listener for input
 */
function bool DriverEnter( Pawn userPawn )
{
	local bool driverCouldEnter;
	local GGGoat newDriver;

	if(IsTARDISLocked() || userPawn != TARDISOwner)//Only the owner is allowed to drive
		return false;

	driverCouldEnter = super.DriverEnter( userPawn );

	if( driverCouldEnter )
	{
		//ModifyCameraZoom(PlayerController(Controller));

		/*mHUD=GGHUD( GGPlayerControllerGame(Controller).myHUD ).mHUDMovie;
		if(mHUD.mInventory == none)
		{
			mHUD.AddInventory();
			mHUD.mInventory.Setup();
			mHUD.ShowInventory( false );
			mHUD.mInventoryDescription.Setup();
			mHUD.SetInventoryDescription();
		}
		mHUD.mInventory.OnItemClick=OnInventoryItemClicked;*/

		newDriver=GGGoat(userPawn);
		if(newDriver != none)
		{
			myMut.PassengerEnterTARDIS(newDriver.mCachedSlotNr, TARDISOwner.mCachedSlotNr);
		}
	}

	return driverCouldEnter;
}

/**
 * Take care of the new passenger
 */
function bool PassengerEnter( Pawn userPawn )
{
	local bool driverCouldEnter;
	local GGGoat newPassenger;

	if(IsTARDISLocked())
		return false;

	driverCouldEnter = super.PassengerEnter( userPawn );

	if( driverCouldEnter )
	{
		newPassenger=GGGoat(userPawn);
		if(newPassenger != none)
		{
			myMut.PassengerEnterTARDIS(newPassenger.mCachedSlotNr, TARDISOwner.mCachedSlotNr);
		}
	}

	return driverCouldEnter;
}

/**
 * See super.
 */
function GetOutOfVehicle( Pawn userPawn )
{
	super.GetOutOfVehicle( userPawn );

	//ModifyCameraZoom(PlayerController(userPawn.Controller), true);
	/*if(mHold.mOpen)
	{
		ToggleInventory(userPawn.Controller);
	}
	mHUD.mInventory.OnItemClick=mHUD.OnInventoryItemClicked;*/
}

event bool DriverLeave( bool bForceLeave )
{
	local bool didLeave;
	local GGGoat oldDriver;

	if(IsTARDISLocked())
		return false;

	oldDriver=GGGoat(Driver);
	didLeave=super.DriverLeave(bForceLeave);
	if(didLeave && oldDriver != none)
	{
		myMut.PassengerLeaveTARDIS(oldDriver.mCachedSlotNr);
	}

	return didLeave;
}

function PassengerLeave( int seatIndex )
{
	super.PassengerLeave(seatIndex);
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	super.KeyState(newKey, keyState, PCOwner);

	if(PCOwner != Controller || !ShouldListenToDriverInput())
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			SetTimer(1.f, false, NameOf(SpaceTravel));
		}
		else if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			SetTimer(1.f, false, NameOf(TimeTravel));
		}
		else if( localInput.IsKeyIsPressed( "GBA_Jump", string( newKey ) ) )
		{
			ChangeDestination();
		}
		/*else if( localInput.IsKeyIsPressed( "GBA_ToggleInventory", string( newKey ) ) )
		{
			ToggleInventory(Controller);
		}
		else if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			if( mHUD.mInventoryOpen )
			{
				RemoveFromInventory( lastSelectedIndex );
			}
			else
			{
				mHold.RemoveFromInventory(0);
			}
		}
		else if( newKey == 'Escape' || newKey == 'XboxTypeS_Start')
		{
			if( mHUD.mInventoryOpen )
			{
				ToggleInventory(Controller);
			}
		}*/
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			ClearTimer(NameOf(SpaceTravel));
		}
		else if( localInput.IsKeyIsPressed( "GBA_ToggleRagdoll", string( newKey ) ) )
		{
			ClearTimer(NameOf(TimeTravel));
		}
	}
}

function TimeTravel()
{
	if(IsTARDISLocked())
		return;

	wantTimeTravel=true;
	TARDISLeave();
}

function SpaceTravel()
{
	if(IsTARDISLocked())
		return;

	wantTeleport=true;
	TARDISLeave();
}

function TARDISLeave()
{
	isLeaving=true;

	SetTimer(mTARDISLeaveSound.Duration, false, NameOf(TARDISLeft));
	SetTimer(4.f, false, NameOf(StartBlink));
	SetTimer(mTARDISLeaveSound.Duration-1.f, false, NameOf(StopBlink));

	PlaySound(mTARDISLeaveSound);
}

function TARDISLeft()
{
	isLeaving=false;
	SetHidden(true);
	if(wantTimeTravel)
	{
		PerformTimeTravel();
	}
	else if(wantTeleport)
	{
		PerformTeleport();
	}
}

function ChangeDestination()
{
	WorldInfo.Game.Broadcast(self, "new destination selected: " $ myMut.ChangeDestination(mMapIndex));
}
//Teleport the TARDIS to the pointed location
function PerformTeleport()
{
	wantTeleport=false;

	mExpectedLocation=mGhostTARDIS.Location;
	SetRotation(mGhostTARDIS.Rotation);

	TARDISLand();
}
//Teleport to a random map
function PerformTimeTravel()
{
	wantTimeTravel=false;

	myMut.ChangeMapRandomly(mMapIndex+1);

	TARDISLand();
}

function TARDISLand()
{
	isLanding=true;

	SetTimer(mTARDISLandSound.Duration, false, NameOf(TARDISLanded));
	SetTimer(1.f, false, NameOf(StartBlink));
	SetTimer(mTARDISLandSound.Duration-1.f, false, NameOf(StopBlink));

	PlaySound(mTARDISLandSound);
}

function TARDISLanded()
{
	isLanding=false;
	SetHidden(false);
}

function StartBlink()
{
	mShouldBlink=true;
}

function StopBlink()
{
	mShouldBlink=false;
	if(isLeaving)
	{
		SetHidden(true);
	}
	if(isLanding)
	{
		SetHidden(false);
	}
}

function Blink()
{
	SetHidden(!bHidden);
}

/*function AddItemToHold(Actor act)
{
	if(GGPawn(act) != none && PlayerController(GGPawn(act).Controller) != none)
	{
		TryToDrive(GGPawn(act));
	}
	else if( GGInventoryActorInterface( act ) != none )
	{
		mHold.AddToInventory( act );
		shouldPopulate=true;
	}
}*/

/*********************************************************************************************
 SCORE ACTOR INTERFACE
*********************************************************************************************/

/**
 * Human readable name of this actor.
 */
function string GetActorName()
{
	return mScoreActorName;
}

/**
 * How much score this actor gives.
 */
function int GetScore()
{
	return mScore;
}

/*********************************************************************************************
 END SCORE ACTOR INTERFACE
*********************************************************************************************/

/**
 * Only care for collisions at a certain interval.
 */
function bool IsPreviousCollisionTooRecent()
{
	local float timeSinceLastCollision;

	timeSinceLastCollision = WorldInfo.TimeSeconds - mLastCollisionData.CollisionTimestamp;

	return timeSinceLastCollision < mMinTimeBetweenCollisions;
}

function bool ShouldCollide( Actor other )
{
	local GGGoat goatDriver, goatPassenger;
	local int i;

	goatDriver = GGGoat( Driver );

	if( other == Driver || IsPreviousCollisionTooRecent() || ( goatDriver != none && goatDriver.mGrabbedItem == other ) )
	{
		return false;
	}

	for( i = 0; i < mPassengerSeats.Length; i++)
	{
		goatPassenger = GGGoat( mPassengerSeats[ i ].PassengerPawn );

		if( goatPassenger != none && goatDriver.mGrabbedItem == other )
		{
			// We do not want to collide with stuff carried by driver or passengers.
			return false;
		}
	}

	return true;
}

/*********************************************************************************************
 GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function bool CanBeGrabbed( Actor grabbedByActor, optional name boneName = '' )
{
	return false;
}

function OnGrabbed( Actor grabbedByActor );
function OnDropped( Actor droppedByActor );

function name GetBoneName( vector grabLocation )
{
	return '';
}

function PrimitiveComponent GetGrabbableComponent()
{
	return CollisionComponent;
}

function GGPhysicalMaterialProperty GetPhysProp()
{
	return none;
}

/*********************************************************************************************
 END GRABBABLE ACTOR INTERFACE
*********************************************************************************************/

function Crash( Actor other, vector hitNormal );//Nope

function bool ShouldCrashKickOutDriver( vector hitVelocity, vector otherHitVelocity )
{
	return false;
}

/*function ToggleInventory(Controller cntr)
{
	local GGPlayerInputGame localInput;

	localInput = GGPlayerInputGame( PlayerController( cntr ).PlayerInput );
	mHold.ToggleOpen();
	shouldPopulate=true;

	localInput.Outer.mInventoryOpen = !localInput.Outer.mInventoryOpen;
	localInput.GoToState( localInput.Outer.mInventoryOpen ? 'InventoryOpen' : '' );
}*/

/*function OnInventoryItemClicked( GGUIScrollingList Sender, GFxObject ItemRenderer, int Index, int ControllerIdx, int ButtonIdx, bool IsKeyboard )
{
	if( mHUD.mInventoryOpen )
	{
		RemoveFromInventory( Index );
	}
}*/

/*function RemoveFromInventory( int index )
{
	mHold.RemoveFromInventory( index );
	shouldPopulate=true;
}*/

/*function PopulateInventory()
{
	local int i;
	local GFxObject tempObject, dataProviderArray, dataProviderObject;
	local array<ASValue> args;

	shouldPopulate=false;
	dataProviderArray = mHUD.CreateArray();

	for( i = 0; i < mHold.mInventorySlots.Length; ++i )
	{
		//WorldInfo.Game.Broadcast(self, "inventoryItem=" $ mHold.mInventorySlots[ i ].mName);
		tempObject = mHUD.CreateObject( "Object" );

		tempObject.SetString( "label", mHold.mInventorySlots[ i ].mName );

		dataProviderArray.SetElementObject( i, tempObject );
	}

	dataProviderObject = mHUD.mRootMC.CreateDataProviderFromArray( dataProviderArray );

	mHUD.mInventory.SetObject( "dataProvider", dataProviderObject );

   	args.Length = 0;
	mHUD.mInventory.Invoke( "validateNow", args );
	mHUD.mInventory.Invoke( "invalidateData", args );
}*/

/**
 * Called when a pawn is possessed by a controller.
 */
function NotifyOnPossess( Controller C, Pawn P )
{
	local int i;

	if(P == self)
	{
		ModifyCameraZoom(PlayerController(C));
	}
	for( i = 0; i < mPassengerSeats.Length; i++ )
	{
		if( mPassengerSeats[ i ].VehiclePassengerSeat == P )
		{
			ModifyCameraZoom(PlayerController(C), false, true);
		}
	}
}

/**
 * Called when a pawn is unpossessed by a controller.
 */
function NotifyOnUnpossess( Controller C, Pawn P )
{
	local int i;

	if(P == self)
	{
		ModifyCameraZoom( PlayerController(C), true);
	}
	for( i = 0; i < mPassengerSeats.Length; i++ )
	{
		if( mPassengerSeats[ i ].VehiclePassengerSeat == P )
		{
			ModifyCameraZoom(PlayerController(C), true, true);
		}
	}
}

DefaultProperties
{
	// --- TARDISVehicle
	Begin Object class=StaticMeshComponent Name=StaticMeshComp_0
		//StaticMesh=StaticMesh'Zombie_Props.mesh.portableToilet'
		StaticMesh=StaticMesh'Space_Museum.Meshes.Turdis'
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=50.0f //if too big, we won't get any notifications from collisions between kactors
		CollideActors=true
		BlockActors=true
		BlockZeroExtent=true
		BlockNonZeroExtent=true
		Translation=(Z=-50)
		Rotation=(Yaw=16384)
	End Object
	CollisionComponent=StaticMeshComp_0
	Components.Add(StaticMeshComp_0)

	Physics=PHYS_None

	mTeleportRange=100000

	mMinTimeBetweenCollisions=3.0f

	mScoreActorName="TARDIS"
	mScore=42

	mJumpForceSize=100000000.0f

	// --- GGSVehicle
	mGentlePushForceSize=3700.0f

	mNumberOfSeats=3

	mDriverSocketName=""

	mCameraLookAtOffset=(X=0.0f,Y=0.0f,Z=150.0f)
	CamDist=2000.f

	// --- Actor
	bNoEncroachCheck=true
	mBlockCamera=false

	// --- Pawn
	ViewPitchMin=-16000
	ViewPitchMax=16000

	GroundSpeed=4200
	AirSpeed=4200

	// --- SVehicle
	// The speed of the vehicle is controlled by MaxSpeed, GroundSpeed, AirSpeed and TorqueVSpeedCurve
	MaxSpeed=4200					// Absolute max physics speed
	MaxAngularVelocity=110000.0f	// Absolute max physics angular velocity (Unreal angular units)

	COMOffset=(x=0.0f,y=0.0f,z=0.0f)

	bDriverIsVisible=false

	Begin Object Name=CollisionCylinder
		//CollisionRadius=100.0f
		//CollisionHeight=100.0f
		BlockNonZeroExtent=false
		BlockZeroExtent=false
		BlockActors=false
		BlockRigidBody=false
		CollideActors=false
	End Object

	CollisionSound=SoundCue'MMO_IMPACT_SOUND.Cue.IMP_Wood_large_Boxy_Cupboard_Cue'

	Begin Object class=AnimNodeSequence Name=MyMeshSequence
    End Object

	Begin Object name=SVehicleMesh
		SkeletalMesh=SkeletalMesh'DrivenVehicles.mesh.Bicycle_Skele_02'
		bHasPhysicsAssetInstance=false
		scale=0.1.f
		/*
		SkeletalMesh=SkeletalMesh'UFO.mesh.UFO_Skele_01'
		PhysicsAsset=PhysicsAsset'UFO.mesh.UFO_Skele_01_Physics'//This have a crappy collision box
		Animations=MyMeshSequence
		AnimSets(0)=AnimSet'UFO.Anim.UFO_Anim_01'
		bHasPhysicsAssetInstance=true
		RBChannel=RBCC_Vehicle
		RBCollideWithChannels=(Untitled2=false,Untitled3=true,Vehicle=true)
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=1
		Rotation=(Pitch=-16384,Yaw=0,Roll=0)
		*/
	End Object

	Begin Object Class=UDKVehicleSimCar Name=SimulationObject
		bClampedFrictionModel=true
		TorqueVSpeedCurve=(Points=((InVal=-600.0,OutVal=0.0),(InVal=-300.0,OutVal=130.0),(InVal=0.0,OutVal=210.0),(InVal=900.0,OutVal=130.0),(InVal=1450.0,OutVal=10.0),(InVal=1850.0,OutVal=0.0)))
		MaxSteerAngleCurve=(Points=((InVal=0,OutVal=35),(InVal=500.0,OutVal=18.0),(InVal=700.0,OutVal=14.0),(InVal=900.0,OutVal=9.0),(InVal=970.0,OutVal=7.0),(InVal=1500.0,OutVal=3.0)))
		SteerSpeed=85
		NumWheelsForFullSteering=2
		MaxBrakeTorque=200.0f
		EngineBrakeFactor=0.08f
	End Object
	SimObj=SimulationObject
	Components.Add(SimulationObject)

	// Vehicle
	ExitPositions(0)=(X=-200.0f,Y=0.0f,Z=0.0f)
	ExitPositions(1)=(X=-200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(2)=(X=-200.0f,Y=200.0f,Z=0.0f)
	ExitPositions(3)=(X=0.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(4)=(X=0.0f,Y=200.0f,Z=0.0f)
	ExitPositions(5)=(X=200.0f,Y=0.0f,Z=0.0f)
	ExitPositions(6)=(X=200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(7)=(X=200.0f,Y=200.0f,Z=0.0f)

	mTARDISLeaveSound=SoundCue'GoatorWho.TardisTakeOffCue'
	mTARDISLandSound=SoundCue'GoatorWho.TardisLandingCue'
}
