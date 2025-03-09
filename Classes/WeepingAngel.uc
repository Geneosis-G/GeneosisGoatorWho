class WeepingAngel extends GGStalkerAbstract;

var GoatorWho myMut;

var float mLastRelocationTime;
var bool mWasSeen;
var bool mIsAttacking;
var float mSightRadius;

var SkeletalMeshComponent mWings;
var float mWhiteScreenTimer;
var rotator lockedRot;
var SoundCue mWeepingAngelSound;
var SoundCue mCatchSound;

simulated event PostBeginPlay()
{
	local PlayerController PC;
	local int count, i, randPC;
	local SkelControlLookAt tmpControl;

	SkeletalMeshComponent.SetAnimTreeTemplate( mAnimTree );
	SkeletalMeshComponent.AnimSets[ 0 ] = mAnimSet;

	mAnimNodeSlot = AnimNodeSlot( SkeletalMeshComponent.FindAnimNode( 'FullBodySlot' ) );
	PlayCorrectAnim();

	SkeletalMeshComponent.AttachComponent(mWings, 'Spine_01', vect(20, 0, 30), rot(16384, 0, 0), 1.5f * vect(1, 1, 1));
	mWings.SetLightEnvironment(SkeletalMeshComponent.LightEnvironment);
	mWings.GlobalAnimRateScale = 0.5f;
	SetTimer(0.4f, false, NameOf(StopWings));

	foreach WorldInfo.AllControllers(class'PlayerController', PC)
	{
		count++;
	}

	randPC=Rand(count);
	foreach WorldInfo.AllControllers(class'PlayerController', PC)
	{
		if(i == randPC)
		{
			AssosiateWithPC(GGPlayerControllerGame(PC));
			break;
		}
		i++;
	}

	//Make sure statues are not pointing randomly
	if( SkeletalMeshComponent.FindSkelControl( 'HeadControl' ) != none )
	{
		tmpControl = SkelControlLookAt( SkeletalMeshComponent.FindSkelControl( 'HeadControl' ) );
		tmpControl.TargetLocationSpace = BCS_WorldSpace;
		tmpControl.SetSkelControlActive( false );
	}

	if( SkeletalMeshComponent.FindSkelControl( 'ArmLControl' ) != none )
	{
		tmpControl = SkelControlLookAt( SkeletalMeshComponent.FindSkelControl( 'ArmLControl' ) );
		tmpControl.TargetLocationSpace = BCS_WorldSpace;
		tmpControl.SetSkelControlActive( false );
	}

	if( SkeletalMeshComponent.FindSkelControl( 'ArmRControl' ) != none )
	{
		tmpControl = SkelControlLookAt( SkeletalMeshComponent.FindSkelControl( 'ArmRControl' ) );
		tmpControl.TargetLocationSpace = BCS_WorldSpace;
		tmpControl.SetSkelControlActive( false );
	}
	//Find Goator Who mut
	foreach AllActors(class'GoatorWho', myMut)
		break;
}

function StopWings()
{
	mWings.GlobalAnimRateScale = 0.f;
}

function PlayCorrectAnim()
{
	local name animToPlay;
	local float animDuration;

	animToPlay = mIsAttacking?'FenceLeaning':'Scared';
	animDuration = SkeletalMeshComponent.GetAnimLength( animToPlay );

	mAnimNodeSlot.StopCustomAnim(0.f);
	mAnimNodeSlot.PlayCustomAnimByDuration( animToPlay, animDuration,,, true );
	SkeletalMeshComponent.GlobalAnimRateScale = 0.f;
}

simulated event Tick( float delta )
{
	local bool shouldHide;

	super(SkeletalMeshActor).Tick( delta );

	if( mAssociatedPC == none )
		return;
	//Lock pawn in place if being teleported
	if(lockedRot != rot(0, 0, 0))
	{
		mAssociatedPC.Pawn.SetRotation(lockedRot);
	}

	if(mHasRelocated && `TimeSince( LastRenderTime ) > mTimeNotLookingForHide)
	{
		if(mHasBeenSeen)
		{
			shouldHide=true;
		}
		else if(`TimeSince( mLastRelocationTime ) > mTimeNotLookingForHide)
		{
			shouldHide=true;
		}
	}

	if(shouldHide)
	{
		//Make angel unable to dissapear if seen by other angel
		if(!IsAngelSeenByAngel(false))
		{
			mHasRelocated = false;
			SetLocation( vect( 0.0f, 0.0f, 0.0f ) );
		}
		//If two angels see each other, unlock no angel mutator
		if(!class'NoAngels'.default.isNoAngelsUnlocked
		&& IsAngelSeenByAngel(true))
		{
			class'NoAngels'.static.UnlockNoAngels();
		}
	}
	else if(!mHasRelocated)
	{
		if(IsRelocationAllowed())
		{
			Relocate();
		}
		else // Make sure angels won't teleport all at once
		{
			mHasRelocated=true;
			mLastRelocationTime=WorldInfo.TimeSeconds;
			mTimeNotLookingForHide=RandRange(1.f, 5.f);
		}
	}

	mHasBeenSeen = `TimeSince( LastRenderTime ) < 0.5f;
	mWasSeen = mWasSeen || mHasBeenSeen;
}

function bool IsRelocationAllowed()
{
	return GGGoat(mAssociatedPC.Pawn) == none
		|| (!GGGoat(mAssociatedPC.Pawn).mIsInAir && !GGGoat(mAssociatedPC.Pawn).mIsInWater);
}

function Relocate()
{
	local WeepingAngel tmpWA;
	local bool placementOK;
	local rotator randRot, newRotation;;
	local vector dest, newRight, hitNormal, X, Y;
	local float minDist;
	local GGPawn targetPawn;

	SetHidden(true);//Avoid blinking in case of multiple relocation

	super.Relocate();
	//Fix rotation
	GetAxes(Rotation, X, Y, hitNormal);
	if(hitNormal.Z <= 0.1f)
	{
		hitNormal = vect(0, 0, 1);

		newRight = hitNormal cross Normal( mAssociatedPC.Pawn.Location - Location );
	  	newRotation = rotator( newRight cross hitNormal );

		SetRotation( newRotation );
	}
	targetPawn = GGPawn(mAssociatedPC.Pawn);
	if(GGGoat(targetPawn) == none)
	{
		GetAxes(Rotation, X, Y, hitNormal);
		newRight = hitNormal cross Normal( mAssociatedPC.Pawn.Location - Location );
	  	newRotation = rotator( newRight cross hitNormal );

		SetRotation( newRotation );
	}
	//Make sure angels don't spawn on top of each other
	minDist=CylinderComponent(CollisionComponent).CollisionRadius * 2.f;
	while(!placementOK)
	{
		placementOK=true;
		foreach myMut.mWeepingAngels(tmpWA)
		{
			if(tmpWA == self)
				continue;

			if(VSize(Location - tmpWA.Location) <= minDist)
			{
				placementOK=false;
				randRot.Yaw=Rand(65536);
				dest=tmpWA.Location + vector(randRot) * (minDist + 1.f);
				SetLocation(dest);
			}
		}
	}

	mLastRelocationTime=WorldInfo.TimeSeconds;
	mTimeNotLookingForHide=RandRange(1.f, 5.f);

	mIsAttacking=mWasSeen && !AngelSeeAngels();
	if(mIsAttacking)
	{
		PlaySound( mWeepingAngelSound );
	}
	PlayCorrectAnim();
	mWasSeen=false;
	//if agressive angel teleported on top of a player, teleport him to random map
	if(mIsAttacking
	&& targetPawn != none
	&& VSize2D(targetPawn.Location - Location) < CylinderComponent(CollisionComponent).CollisionRadius + targetPawn.GetCollisionRadius())
	{
  		//WorldInfo.Game.Broadcast(self, self @ "Gotcha!");
  		lockedRot=targetPawn.Rotation;
  		targetPawn.CustomTimeDilation=0.f;
  		StartEffect();
  		SetTimer(mWhiteScreenTimer, false, 'StopEffectAndChangeMap');
	}

	SetHidden(false);
}

function StartEffect()
{
	local LocalPlayer localPlayer;
	local PostProcessSettings pps;

	WorldInfo.Game.SetGameSpeed(0.25f);

	pps.Scene_HighLights=vect(0, 0, 0);
	localPlayer=LocalPlayer(mAssociatedPC.Player);
	localPlayer.OverridePostProcessSettings(pps, mWhiteScreenTimer);

	PlaySound(mCatchSound);
}

function StopEffectAndChangeMap()
{
	local LocalPlayer localPlayer;

	localPlayer=LocalPlayer(mAssociatedPC.Player);
	localPlayer.ClearPostProcessSettingsOverride();

	myMut.ChangeMapRandomly();
}

function bool IsAngelSeenByAngel(bool testBothSeen)
{
	local WeepingAngel tmpWA;

	if(testBothSeen && !mIsAttacking)
	{
		return false;
	}

	foreach myMut.mWeepingAngels(tmpWA)
	{
		if(tmpWA == self || !tmpWA.mIsAttacking)
			continue;

		if(IsInSight(self, tmpWA))
		{
			if(testBothSeen)
			{
				if(IsInSight(tmpWA, self))
				{
					return true;
				}
			}
			else
			{
				return true;
			}
		}
	}

	return false;
}

function bool AngelSeeAngels()
{
	local WeepingAngel tmpWA;

	foreach myMut.mWeepingAngels(tmpWA)
	{
		if(tmpWA == self)
			continue;

		if(IsInSight(tmpWA, self))
		{
			return true;
		}
	}

	return false;
}

function bool IsInSight(WeepingAngel target, WeepingAngel source)
{
	return VSize(target.Location - source.Location) <= mSightRadius
		&& acos( Normal( vector(source.Rotation) ) dot Normal( target.Location - source.Location )) < 0.785398f
		&& !GeometryBetween( source, target );
}

function bool GeometryBetween( Actor source, Actor other )
{
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;
	local float sourceRadius, sourceHeight, otherHeight, otherRadius;
	local bool itemInSight;

	if( other != none )
	{
		source.GetBoundingCylinder( sourceRadius, sourceHeight );

		traceStart = source.Location;
		//DrawDebugCylinder(traceStart, traceStart + (vect(0, 0, -1) * sourceHeight), sourceRadius, 10, 255, 255, 255, true);
		other.GetBoundingCylinder( otherRadius, otherHeight );

		traceEnd = other.Location;
		//DrawDebugCylinder(traceEnd, traceEnd + (vect(0, 0, -1) * otherHeight), otherRadius, 10, 155, 155, 155, true);
		//See head?
		itemInSight=false;
		foreach TraceActors( class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart )
		{
			if(Volume(hitActor) == none
			&& GGApexDestructibleActor(hitActor) == none
			&& hitActor != source
			&& hitActor != other)
			{
				itemInSight=true;
			}
		}
		if(!itemInSight)
			return false;
		//See body?
		itemInSight=false;
		traceEnd.Z -= otherHeight/2.f;
		foreach TraceActors( class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart )
		{
			if(Volume(hitActor) == none
			&& GGApexDestructibleActor(hitActor) == none
			&& hitActor != source
			&& hitActor != other)
			{
				itemInSight=true;
			}
		}
		if(!itemInSight)
			return false;
		//See foot?
		itemInSight=false;
		traceEnd.Z -= otherHeight/2.f;
		foreach TraceActors( class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart )
		{
			if(Volume(hitActor) == none
			&& GGApexDestructibleActor(hitActor) == none
			&& hitActor != source
			&& hitActor != other)
			{
				itemInSight=true;
			}
		}
		if(!itemInSight)
			return false;
	}

	return true;
}

DefaultProperties
{
	mSightRadius=5000.f
	mWhiteScreenTimer=1.5f

	Begin Object name=SkeletalMeshComponent0
		SkeletalMesh=SkeletalMesh'Characters.mesh.CasualGirl_01'
		PhysicsAsset=PhysicsAsset'Characters.mesh.CasualGirl_Physics_01'
		AnimSets(0)=AnimSet'Characters.Anim.Characters_Anim_01'
		AnimTreeTemplate=AnimTree'Characters.Anim.Characters_Animtree_01'
		Translation=(Z=-160)
		Materials(0)=MaterialInstanceConstant'GoatorWho.Concrete_Light_Mat_01'
	End Object

	mAnimSet=AnimSet'Characters.Anim.Characters_Anim_01'
	mAnimTree=AnimTree'Characters.Anim.Characters_Animtree_01'

	//mRelocationSoundCue=none
	mHurtSoundCue=SoundCue'MMO_IMPACT_SOUND.Cue.IMP_Medium_Stone_Cue'
	mWeepingAngelSound=SoundCue'GoatorWho.WeepingAngelCue'

	mCatchSound=SoundCue'Goat_Sounds.Cue.Fan_Jump_Cue'

	mTimeSinceLastRenderRelocate=0.f
	mTimeNotLookingForHide=3.0f

	Begin Object class=SkeletalMeshComponent Name=WingMesh
		SkeletalMesh=SkeletalMesh'MMO_Wings.Mesh.Wings_01'
		PhysicsAsset=PhysicsAsset'MMO_Wings.Mesh.Wings_Physics_01'
		AnimSets(0)=AnimSet'MMO_Wings.Anim.Wings_Anim_01'
		AnimTreeTemplate=AnimTree'MMO_Wings.Anim.Wings_AnimTree'
		Materials(0)=MaterialInstanceConstant'GoatorWho.Concrete_Light_Mat_01'
		bHasPhysicsAssetInstance=true
		bCacheAnimSequenceNodes=false
		AlwaysLoadOnClient=true
		AlwaysLoadOnServer=true
		bOwnerNoSee=false
		CastShadow=true
		BlockRigidBody=true
		CollideActors=true
		bUpdateSkelWhenNotRendered=false
		bIgnoreControllersWhenNotRendered=true
		bUpdateKinematicBonesFromAnimation=true
		bCastDynamicShadow=true
		RBChannel=RBCC_Untitled3
		RBCollideWithChannels=(Untitled1=false,Untitled2=false,Untitled3=true,Vehicle=true)
		bOverrideAttachmentOwnerVisibility=true
		bAcceptsDynamicDecals=false
		TickGroup=TG_PreAsyncWork
		MinDistFactorForKinematicUpdate=0.0
		bChartDistanceFactor=true
		RBDominanceGroup=15
		bSyncActorLocationToRootRigidBody=true
		bNotifyRigidBodyCollision=true
		ScriptRigidBodyCollisionThreshold=1
        BlockActors=TRUE
		AlwaysCheckCollision=TRUE
	End Object
	mWings=WingMesh

	bStatic=false
	bNoDelete=false
}