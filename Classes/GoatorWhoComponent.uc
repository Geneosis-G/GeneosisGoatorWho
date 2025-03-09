class GoatorWhoComponent extends GGMutatorComponent;

var GGGoat gMe;
var GoatorWho myMut;

var StaticMeshComponent sonicScrewMesh;
var TARDISVehicle myTARDIS;

var float mSonicScrewFixTime;
var float mSonicScrewRadius;
var SoundCue mSonicScrewSound;
var AudioComponent mAC;
var SoundCue mRepairSound;
var ParticleSystem mRepairParticle;

function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=GoatorWho(owningMutator);

		myMut.CreateTARDISPassenger(goat.mCachedSlotNr);

		SpawnTARDIS();

		sonicScrewMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponent( sonicScrewMesh, 'Head', vect(0.f, 0.f, 12.f));
	}
}

function vector FindTeleportLocation(vector destination)
{
	local vector traceStart, traceEnd, hitLocation, hitNormal, itemExtent, itemExtentOffset;
	local Actor hitActor;
	local box itemBoundingBox;

	traceStart = destination + vect(0, 0, 150);
	traceEnd = destination + vect(0, 0, -150);

	myTARDIS.GetComponentsBoundingBox( itemBoundingBox );
	itemExtent = ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f;
	itemExtentOffset = itemBoundingBox.Min + ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f - myTARDIS.Location;

	foreach myMut.TraceActors( class'Actor', hitActor, hitLocation, hitNormal, traceEnd, traceStart, itemExtent)
	{
		if(hitActor == myTARDIS
		|| hitActor == gMe
		|| hitActor.Owner == gMe
		|| Volume(hitActor) != none)
		{
			continue;
		}

		break;
	}

	if(hitActor == none)
	{
		hitLocation=destination;
	}

	return hitLocation - itemExtentOffset;
}

function SpawnTARDIS()
{
	local vector spawnLoc;

	if(myTARDIS != none && !myTARDIS.bPendingDelete)
		return;

	spawnLoc=gMe.Location + (Normal(vector(gMe.Rotation)) * 300.f);
	spawnLoc.Z = spawnLoc.Z - gMe.GetCollisionHeight();

	myTARDIS=myMut.Spawn(class'TARDISVehicle', gMe,, spawnLoc, gMe.Rotation,, true);
	//myMut.WorldInfo.Game.Broadcast(myMut, "spawned myTARDIS=" $ myTARDIS);
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PlayerController( gMe.Controller ).PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			ActivateSonicScrewdriver(true);
		}
		else if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			if(gMe.mIsRagdoll)
			{
				gMe.SetTimer(1.f, false, NameOf(EmergencyCall), self);
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_Special", string( newKey ) ) )
		{
			ActivateSonicScrewdriver(false);
		}
		else if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			gMe.ClearTimer(NameOf(EmergencyCall), self);
		}
	}
}

function ActivateSonicScrewdriver(bool activate)
{
	gMe.ClearTimer(NameOf(FixItem), self);

	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = gMe.CreateAudioComponent( mSonicScrewSound, false );
	}
	if(activate)
	{
		if(!mAC.IsPlaying())
		{
			mAC.Play();
		}
		gMe.SetTimer(mSonicScrewFixTime, true, NameOf(FixItem), self);
	}
	else
	{
		if(mAC.IsPlaying())
		{
			mAC.Stop();
		}
	}
}

function FixItem()
{
	local vector loc;

	loc=FixClosestItem();
	if(!IsZero(loc))
	{
		gMe.PlaySound(mRepairSound);
		gMe.WorldInfo.MyEmitterPool.SpawnEmitter(mRepairParticle, loc);
	}
}

function vector FixClosestItem()
{
	local GGExplosiveActorWreckable tmpExplodedAct, explodedActToFix;
	local GGApexDestructibleActor tmpApexAct, apexActToFix;
	local GGExplodedVehicle tmpCar, carToFix;
	local Actor closestAct;
	local float minDistExp, minDistApex, minDistCar, dist;
	local vector effectLoc;

	minDistCar=-1;
	foreach myMut.CollidingActors(class'GGExplodedVehicle', tmpCar, mSonicScrewRadius, gMe.Location, true)
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, "tmpExplodedAct=" $ tmpExplodedAct $ ", exp=" $ tmpExplodedAct.mIsExploding);
		dist=VSizeSq(tmpCar.Location - gMe.Location);
		if(minDistCar == -1 || dist<minDistCar)
		{
			minDistCar=dist;
			carToFix=tmpCar;
		}
	}
	minDistExp=-1;
	foreach myMut.CollidingActors(class'GGExplosiveActorWreckable', tmpExplodedAct, mSonicScrewRadius, gMe.Location, true)
	{
		//myMut.WorldInfo.Game.Broadcast(myMut, "tmpExplodedAct=" $ tmpExplodedAct $ ", exp=" $ tmpExplodedAct.mIsExploding);
		if(!tmpExplodedAct.mIsExploding)
			continue;

		dist=VSizeSq(tmpExplodedAct.Location - gMe.Location);
		if(minDistExp == -1 || dist<minDistExp)
		{
			minDistExp=dist;
			explodedActToFix=tmpExplodedAct;
		}
	}
	minDistApex=-1;
	foreach myMut.CollidingActors(class'GGApexDestructibleActor', tmpApexAct, mSonicScrewRadius, gMe.Location, true)
	{
		if(!tmpApexAct.mIsFractured)
			continue;

		dist=VSizeSq(tmpApexAct.Location - gMe.Location);
		if(minDistApex == -1 || dist<minDistApex)
		{
			minDistApex=dist;
			apexActToFix=tmpApexAct;
		}
	}
	closestAct=GetClosestAct(gMe, carToFix, explodedActToFix, apexActToFix);
	if(carToFix != none && carToFix == closestAct)
	{
		effectLoc=carToFix.Location;
		if(FixCar(carToFix))
		{
			return effectLoc;
		}
	}
	if(explodedActToFix != none && explodedActToFix == closestAct)
	{
		effectLoc=explodedActToFix.Location;
		if(FixExploded(myMut.mExplodedActors.Find('expAct', explodedActToFix)))
		{
			return effectLoc;
		}
	}
	if(apexActToFix != none && apexActToFix == closestAct)
	{
		effectLoc=apexActToFix.Location;
		if(FixBrokenKActor(myMut.mBreakableKactors.Find('apexArchetype', GGApexDestructibleActor(apexActToFix.ObjectArchetype)), apexActToFix))
		{
			return effectLoc;
		}
		//else
		FixBrokenApex(myMut.mBrokenApex.Find(apexActToFix));
	}

	return effectLoc;
}

function bool FixCar(GGExplodedVehicle carToFix)
{
	local GGRealCar respawnedCar;

	if(carToFix == none)
		return false;

	respawnedCar = gMe.Spawn(carToFix.mRespawnCarClass,,, carToFix.Location, carToFix.Rotation,, true);
	if(respawnedCar == none)
		return false;

	respawnedCar.mesh.SetMaterial( 0, carToFix.mRespawnCarMaterial );
	carToFix.ShutDown();
	carToFix.Destroy();

	return true;
}

function bool FixExploded(int index)
{
	local int i;
	local bool meshSwitchWasSuccessful;

	if(index == INDEX_NONE)
		return false;

	meshSwitchWasSuccessful = myMut.mExplodedActors[index].expAct.StaticMeshComponent.SetStaticMesh(myMut.mExplodedActors[index].oldMesh, true);
	//myMut.WorldInfo.Game.Broadcast(myMut, "meshSwitchWasSuccessful=" $ meshSwitchWasSuccessful);
	if( meshSwitchWasSuccessful )
 	{
 		for(i=0 ; i<myMut.mExplodedActors[index].oldMats.Length ; i++)
 		{
 			myMut.mExplodedActors[index].expAct.StaticMeshComponent.SetMaterial(i, myMut.mExplodedActors[index].oldMats[i]);
 		}
		myMut.mExplodedActors[index].expAct.mIsExploding=false;
		myMut.mExplodedActors.Remove(index, 1);
	 	return true;
 	}
	//Something went wrong in mesh replacement, this should not happen
	return false;
}

function bool FixBrokenKActor(int index, GGApexDestructibleActor apexToFix)
{
	local GGKActorSpawnable newKact;
	local int i;

	if(index == INDEX_NONE || apexToFix == none)
		return false;

 	newKact=myMut.Spawn(class'GGKActorSpawnable',,,apexToFix.Location, apexToFix.Rotation,, true);
 	if(newKact == none)
 		return false;

 	newKact.SetStaticMesh(myMut.mBreakableKactors[index].oldMesh);
 	for(i=0 ; i<myMut.mBreakableKactors[index].oldMats.Length ; i++)
	{
		newKact.StaticMeshComponent.SetMaterial(i, myMut.mBreakableKactors[index].oldMats[i]);
	}

	newKact.mApexActor=GGApexDestructibleActor(apexToFix.ObjectArchetype);
	apexToFix.Destroy();
	newKact.CollisionComponent.WakeRigidBody();

	return true;
}

function bool FixBrokenApex(int index)
{
	local GGApexDestructibleActor newApex;

	if(index == INDEX_NONE)
		return false;

	newApex=myMut.Spawn(class'GGApexDestructibleActor',,,myMut.mBrokenApex[index].Location, myMut.mBrokenApex[index].Rotation, myMut.mBrokenApex[index], true);
	if(newApex == none)
		return false;

	newApex.mIsFractured=false;
	newApex.mBlockCamera=true;
	myMut.mBrokenApex[index].Destroy();

	return true;
}

function Actor GetClosestAct(Actor src, Actor a, Actor b, Actor c)
{
	local float distA, distB, distC;

	if(src == none)
		return none;

	distA=-1;
	if(a != none) distA=VSizeSq(src.Location - a.Location);
	distB=-1;
	if(b != none) distB=VSizeSq(src.Location - b.Location);
	distC=-1;
	if(c != none) distC=VSizeSq(src.Location - c.Location);

	if(distA == -1 && distB == -1 && distC == -1) return none;

	if(distA == -1 && distB == -1) return c;
	if(distA == -1 && distC == -1) return b;
	if(distB == -1 && distC == -1) return a;

	if(distA == -1) return (distB<distC?b:c);
	if(distB == -1) return (distA<distC?a:c);
	if(distC == -1) return (distA<distB?a:b);

	if(distA<=distB && distA<=distC) return a;
	if(distB<=distA && distB<=distC) return b;
	if(distC<=distA && distC<=distB) return c;

	return none;//This should never happen
}

function EmergencyCall()
{
	local vector dest, goatPos;

	if(!gMe.mIsRagdoll)
		return;

	goatPos=gMe.mesh.GetPosition();
	dest=goatPos + (Normal2D(myTARDIS.Location-goatPos) * 300.f);
	dest=FindTeleportLocation(dest);
	//dest.Z=dest.z - gMe.GetCollisionHeight();

	myTARDIS.mGhostTARDIS.SetLocation(dest);
	myTARDIS.mGhostTARDIS.SetRotation(rotator(Normal2D(dest-goatPos)));
	myTARDIS.SpaceTravel();
}

function Tick( float deltaTime )
{
	SpawnTARDIS();
}

/**
 * Called when a pawn is possessed by a controller.
 */
function NotifyOnPossess( Controller C, Pawn P )
{
	super.NotifyOnPossess(C, P);

	myTARDIS.NotifyOnPossess(C, P);
}

/**
 * Called when a pawn is unpossessed by a controller.
 */
function NotifyOnUnpossess( Controller C, Pawn P )
{
	super.NotifyOnUnpossess(C, P);

	myTARDIS.NotifyOnUnpossess(C, P);
}

DefaultProperties
{
	mSonicScrewFixTime=3.f
	mSonicScrewRadius=600.f

	mSonicScrewSound=SoundCue'GoatorWho.SonicScrewCue'
	mRepairSound=SoundCue'MMO_SFX_SOUND.Cue.SFX_Genie_Spells_Wish_Granted_Cue'
	mRepairParticle=ParticleSystem'Zombie_Particles.Particles.Proto_Goat_Buildup'

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Garage.mesh.Garage_Screwu'
		Rotation=(Pitch=0, Yaw=32768, Roll=0)//-16384
		Translation=(X=0, Y=0, Z=0)
		scale=0.5f
	End Object
	sonicScrewMesh=StaticMeshComp1
}