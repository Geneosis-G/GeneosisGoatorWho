class GoatorWho extends GGMutator
	config(Geneosis);

var array<GoatorWhoComponent> mComponents;

struct ExplodedActorInfos{
	var GGExplosiveActorWreckable expAct;
	var StaticMesh oldMesh;
	var array<MaterialInterface> oldMats;
};
var array<ExplodedActorInfos> mExplodedActors;

struct BreakableKActorInfos{
	var GGApexDestructibleActor apexArchetype;
	var StaticMesh oldMesh;
	var array<MaterialInterface> oldMats;
};
var array<BreakableKActorInfos> mBreakableKactors;

var array<GGApexDestructibleActor> mBrokenApex;

var array<string> mAvailableMaps;

struct PassengersInfo{
	var int playerID;
	var int TARDISID;
};
var config array<PassengersInfo> mTARDISPassengers;

var config bool mSeenAngels;
var array<WeepingAngel> mWeepingAngels;

function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local GoatorWhoComponent goatorComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		goatorComp=GoatorWhoComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'GoatorWhoComponent', goat.mCachedSlotNr));
		//WorldInfo.Game.Broadcast(self, "ghostComp=" $ ghostComp);
		if(goatorComp != none && mComponents.Find(goatorComp) == INDEX_NONE)
		{
			mComponents.AddItem(goatorComp);
			if(mAvailableMaps.Length == 0)
			{
				InitMapList();
			}
		}

		if(mComponents.Length == 1)
		{
			RefreshSeenAngels();
		}
	}
}

function InitMapList()
{
	local int i;
	local GGDownloadableContentManager DLCManager;
	local GGCSSDLCManager CSSDLCManager;
	local array<ModInfoStruct> availableMaps, availableModMaps, availableDLCMaps;

	mAvailableMaps.Length=0;

	CSSDLCManager = GGCSSDLCManager( class'GGEngine'.static.GetCSSDLCManager() );
	DLCManager = GGDownloadableContentManager( class'GameEngine'.static.GetDLCManager() );

	CSSDLCManager.GetAvailableMaps( availableDLCMaps );
	DLCManager.GetAvailableMaps( availableModMaps );

	availableMaps = availableDLCMaps;
	for( i = 0; i < availableModMaps.Length; ++i )
	{
		availableMaps.AddItem( availableModMaps[i] );
	}

	for( i = 0; i < availableMaps.Length; ++i )
	{
		if( !class'GGEngine'.static.GetGGEngine().DoesPackageFileExist( availableMaps[i].FileName ) )
		{
			continue;
		}
		if(mAvailableMaps.Find(availableMaps[i].FileName) == INDEX_NONE)
		{
			mAvailableMaps.AddItem(availableMaps[i].FileName);
		}
		//WorldInfo.Game.Broadcast(self, "add map " $ availableMaps[i].FileName);
	}
	//WorldInfo.Game.Broadcast(self, "current map " $ class'WorldInfo'.static.GetWorldInfo().GetMapName());
	//Add hidden maps
	mAvailableMaps.AddItem("Level_MMO_Cowlevel");
	mAvailableMaps.AddItem("Level_MMO_Launchpad");
	mAvailableMaps.AddItem("Level_MMOCity");
	mAvailableMaps.AddItem("Level_Trap");
	//for GoatZ owners
	if(mAvailableMaps.Find("Level_Zombies") != INDEX_NONE)
	{
		mAvailableMaps.AddItem("Level_Zombies_Tutorial");
	}
	//for Payday owners
	if(mAvailableMaps.Find("Level_Heist_01") != INDEX_NONE)
	{
		mAvailableMaps.AddItem("Level_Heist_Moon_01");
	}
}

function ChangeMapRandomly(optional int indexPlusOne)//Index of the map + 1 if not random
{
	local GGGoat goat;
	local PlayerController pc;
	local GGPersistantInventory perInv;
	local string startAtTunnel;
	local string levelToTravelTo;

	class'GGEngine'.static.GetGGEngine().SaveProgression();

	foreach WorldInfo.LocalPlayerControllers( class'PlayerController', pc )
	{
		goat = GGGoat( pc.Pawn );
		if( goat != none && goat.mInventory != none )
		{
			perInv = class'GGGameViewportClient'.static.FindOrAddInventory( LocalPlayer( pc.Player ).ControllerId, WorldInfo.GetMapName( false ) );
			perInv.Clear();

			perInv.SaveInventory( goat.mInventory );
		}
	}

	startAtTunnel = (Rand(2) == 0) ? "?StartAtTunnel" : "";

	levelToTravelTo=GetRandomMapName(indexPlusOne-1);

	ConsoleCommand( "start" @ levelToTravelTo $"?game=" $ PathName( class'WorldInfo'.static.GetWorldInfo().Game.class ) $ "?SkipIntro" $ startAtTunnel, true);
}

function RefreshSeenAngels()
{
	if(mSeenAngels)
	{
		mSeenAngels = false;
		SaveConfig();
	}
	else
	{
		DelayedSpawnWA();
	}
}

function SpawnWA()
{
	local WeepingAngel newWA;

	newWA=Spawn(class'WeepingAngel',,,,,, true);
	mWeepingAngels.AddItem(newWA);

	mSeenAngels = true;
	SaveConfig();

	if(mWeepingAngels.Length < 4)
	{
		DelayedSpawnWA();
	}
}

function DelayedSpawnWA()
{
	ClearTimer(NameOf(SpawnWA));
	SetTimer(60.f * RandRange(5.f, 10.f), false, NameOf(SpawnWA));
}

function int GetRandomMapIndex()
{
	if(mAvailableMaps.Length > 0)
	{
		return Rand(mAvailableMaps.Length);
	}
	else
	{
		return -1;
	}
}

function string ChangeDestination(out int index)
{
	if(mAvailableMaps.Length > 0)
	{
		index++;
		if(index >= mAvailableMaps.Length)
		{
			index=0;
		}
		return mAvailableMaps[index];
	}
	else
	{
		index = -1;
		return class'WorldInfo'.static.GetWorldInfo().GetMapName();
	}
}

function string GetRandomMapName(int index)
{
	if(mAvailableMaps.Length > 0)
	{
		if(index == -1)
		{
			return mAvailableMaps[Rand(mAvailableMaps.Length)];
		}
		else
		{
			return mAvailableMaps[index];
		}
	}
	else
	{
		return class'WorldInfo'.static.GetWorldInfo().GetMapName();
	}
}

function CreateTARDISPassenger(int passenger)
{
	local int index;

	if(mTARDISPassengers.Find('playerID', passenger) == INDEX_NONE)
	{
		index=mTARDISPassengers.Length;
		mTARDISPassengers.Add(1);
		mTARDISPassengers[index].playerID=passenger;
		mTARDISPassengers[index].TARDISID=passenger;
		SaveConfig();
	}
}

function PassengerEnterTARDIS(int passenger, int tardisOwner)
{
	local int index;

	index=mTARDISPassengers.Find('playerID', passenger);
	if(index != INDEX_NONE)
	{
		mTARDISPassengers[index].TARDISID=tardisOwner;
		SaveConfig();
	}
}

function PassengerLeaveTARDIS(int passenger)
{
	local int index;

	index=mTARDISPassengers.Find('playerID', passenger);
	if(index != INDEX_NONE)
	{
		mTARDISPassengers[index].TARDISID=INDEX_NONE;
		SaveConfig();
	}
}

function int GetTARDISForPassenger(int passenger)
{
	local int index;

	index=mTARDISPassengers.Find('playerID', passenger);
	if(index != INDEX_NONE)
	{
		return mTARDISPassengers[index].TARDISID;
	}

	return INDEX_NONE;
}

simulated event Tick( float delta )
{
	local int i;

	super.Tick( delta );

	for( i = 0; i < mComponents.Length; i++ )
	{
		mComponents[ i ].Tick( delta );
	}

	if(!IsTimerActive(NameOf(SpawnDefaultDrivers)))
	{
		SetTimer(1.f, true, NameOf(SpawnDefaultDrivers));
	}
}

function SpawnDefaultDrivers()
{
	local GGRealCar tmpCar;
	local GGExplodedVehicle explodedCar;
	//Give dummy drivers to cars so that their original skin will be saved on desctruction
	foreach WorldInfo.AllPawns(class'GGRealCar', tmpCar)
	{
		if(tmpCar.mDefaultDriver == none)
		{
			SpawnDummyDriver(tmpCar);
		}
	}
	//Make sure cars won't fix by themselves
	foreach DynamicActors(class'GGExplodedVehicle', explodedCar)
	{
		explodedCar.mMinTimeBeforeRespawn=1000000.f;
	}
}

function SpawnDummyDriver(GGRealCar realCar)
{
	local GGNpcHeist npc;

	npc = Spawn( class'GGNpcDummyDriver',,,realCar.Location + vect( 300.0, 0, 0 ),,, true );

	realCar.mDefaultDriver = npc;
}

function OnTakeDamage( Actor damagedActor, Actor damageCauser, int damage, class< DamageType > dmgType, vector momentum )
{
	local GGKactor damagedKact;
	local BreakableKActorInfos newBreakabkeKAct;
	local int i;

	damagedKact=GGKActor(damagedActor);
	if(damagedKact != none && damagedKact.mApexActor != none)
	{
		if(mBreakableKactors.Find('apexArchetype', damagedKact.mApexActor) == INDEX_NONE)
		{
			newBreakabkeKAct.apexArchetype=damagedKact.mApexActor;
			newBreakabkeKAct.oldMesh=damagedKact.StaticMeshComponent.StaticMesh;
			for(i=0 ; i<damagedKact.StaticMeshComponent.GetNumElements() ; i++)
			{
				newBreakabkeKAct.oldMats.AddItem(damagedKact.StaticMeshComponent.GetMaterial(i));
			}
			mBreakableKactors.AddItem(newBreakabkeKAct);
		}
	}
}

/**
 * Called when an actor fractures
 */
function OnFractured( Actor fracturedActor, Actor fractureCauser )
{
	local GGApexDestructibleActor apexAct;

	apexAct=GGApexDestructibleActor(fracturedActor);
	if(apexAct != none)
	{
		//if brokem apex was not a kactor, just save it
		if(mBreakableKactors.Find('apexArchetype', GGApexDestructibleActor(apexAct.ObjectArchetype)) == INDEX_NONE)
		{
			mBrokenApex.AddItem(apexAct);
		}
	}
}

/**
 * Called when an explosive explodes
 */
function OnExplosion( Actor explodedActor )
{
	local GGExplosiveActorWreckable explosiveAct;
	local ExplodedActorInfos newExplodedAct;
	local int i;

	explosiveAct=GGExplosiveActorWreckable(explodedActor);
	if(explosiveAct != none)
	{
		newExplodedAct.expAct=explosiveAct;
		newExplodedAct.oldMesh=explosiveAct.StaticMeshComponent.StaticMesh;
		for(i=0 ; i<explosiveAct.StaticMeshComponent.GetNumElements() ; i++)
		{
			newExplodedAct.oldMats.AddItem(explosiveAct.StaticMeshComponent.GetMaterial(i));
		}
		mExplodedActors.AddItem(newExplodedAct);
	}
}

function StopAngelsSpawn()
{
	ClearTimer(NameOf(SpawnWA));
}

DefaultProperties
{
	mMutatorComponentClass=class'GoatorWhoComponent'
}