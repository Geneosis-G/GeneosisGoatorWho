class NoAngels extends GGMutator
	config(Geneosis);

var array<GGGoat> noAngelsGoats;
var config bool isNoAngelsUnlocked;

/**
 * if the mutator should be selectable in the Custom Game Menu.
 */
static function bool IsUnlocked( optional out array<AchievementDetails> out_CachedAchievements )
{
	//Function not called on custom mutators for now so this is not working
	return default.isNoAngelsUnlocked;
}

/**
 * Unlock the mutator
 */
static function UnlockNoAngels()
{
	if(!default.isNoAngelsUnlocked)
	{
		PostJuice( "Weeping Angels defeated!" );
		PostJuice( "Unlocked 'Leave Me Alone' mutator" );
		default.isNoAngelsUnlocked=true;
		static.StaticSaveConfig();
	}
}

function static PostJuice( string text )
{
	local GGGameInfo GGGI;
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;

	GGGI = GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game );
	GGPCG = GGPlayerControllerGame( GGGI.GetALocalPlayerController() );

	localHUD = GGHUD( GGPCG.myHUD );

	if( localHUD != none && localHUD.mHUDMovie != none )
	{
		localHUD.mHUDMovie.AddJuice( text );
	}
}

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			noAngelsGoats.AddItem(goat);
			ClearTimer(NameOf(InitNoAngels));
			SetTimer(1.f, false, NameOf(InitNoAngels));
		}
	}

	super.ModifyPlayer( other );
}

function InitNoAngels()
{
	local GoatorWho goator;

	//Find Sonic Goat mutator
	foreach AllActors(class'GoatorWho', goator)
	{
		if(goator != none)
		{
			break;
		}
	}

	if(goator == none)
	{
		DisplayUnavailableMessage();
		return;
	}

	//Prevent angels from spawning
	if(noAngelsGoats.Length > 0)
	{
		goator.StopAngelsSpawn();
	}
}

function DisplayUnavailableMessage()
{
	WorldInfo.Game.Broadcast(self, "'Leave me alone' mutator only works if combined with Goator Who.");
	SetTimer(3.f, false, NameOf(DisplayUnavailableMessage));
}

DefaultProperties
{}