class GGNpcDummyDriver extends GGNPCHeist;

simulated event PostBeginPlay()
{
	super.PostBeginPlay();

	SetDrawScale(0.0000001f);
	SetHidden(true);
	SetPhysics(PHYS_None);
	SetCollisionType(COLLIDE_NoCollision);
	CollisionComponent=none;
}