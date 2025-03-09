class TARDISGhost extends DynamicSMActor;

var bool isVisible;

simulated event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	if(isVisible)
	{
		Blink();
	}

}

function SetVisible(bool visible)
{
	SetHidden(!visible);
	return;

	isVisible=visible;
	if(!isVisible)
	{
		SetHidden(true);
	}
}

function Blink()
{
	SetHidden(!bHidden);
}

DefaultProperties
{
	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'Zombie_Props.mesh.portableToilet'
		Translation=(Z=-50)
		Rotation=(Yaw=16384)
		Materials(0)=Material'MMO_GravitationGoat.Materials.Sphere_Mat'
	End Object

	bNoDelete=false
	bStatic=false
}