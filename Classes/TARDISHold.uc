class TARDISHold extends GGInventory;

/**
 * Used when the user removes an item from the inventory
 */
function RemoveFromInventory( int index, optional bool triggerEvent = true )
{
 	super.RemoveFromInventory(index, triggerEvent);

 	if(GGPawn(mLastItemRemoved) != none && !GGPawn(mLastItemRemoved).mIsRagdoll)
 	{
 		GGPawn(mLastItemRemoved).SetPhysics(PHYS_Falling);
 	}
}

/**
 * Where to try spawn the stuff coming out of the inventory.
 */
function vector GetSpawnLocationForItem( GGInventoryActorInterface item )
{
	local Actor itemActor, hitActor;
	local vector spawnLocation, spawnDir, itemExtent, itemExtentOffset, traceStart, traceEnd, traceExtent, hitLocation, hitNormal;
	local box itemBoundingBox;
	local float itemExtentCylinderRadius;

	spawnLocation = vect( 0, 0, 0 );

	itemActor = Actor( item );
	if( itemActor != none )
	{
		spawnLocation = Owner.Location;

		spawnDir = vector( Owner.Rotation );

		itemActor.GetComponentsBoundingBox( itemBoundingBox );

		itemExtent = ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f;
		itemExtentOffset = itemBoundingBox.Min + ( itemBoundingBox.Max - itemBoundingBox.Min ) * 0.5f - itemActor.Location;
		itemExtentCylinderRadius = Sqrt( itemExtent.X * itemExtent.X + itemExtent.Y * itemExtent.Y );

		// Now try fit the thingy into the world.
		// Trace forward.
		traceStart = spawnLocation;
		traceEnd = spawnLocation + spawnDir * itemExtentCylinderRadius * 2.0f;

		hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, false );
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		spawnLocation = hitLocation - spawnDir * itemExtentCylinderRadius;

		//DrawDebugLine( traceStart, traceEnd, 255, 0, 0, true );
		//DrawDebugSphere( hitLocation, 10.0f, 16, 255, 0, 0, true );
		//DrawDebugBox( spawnLocation, vect( 10, 10, 10 ), 255, 0, 0, true );

		// Trace downward.
		traceStart = spawnLocation + vect( 0, 0, 1 ) * itemExtent.Z * 2.0f;
		traceEnd = spawnLocation - vect( 0, 0, 1 ) * itemExtent.Z;
		traceExtent = itemExtent;

		hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, false, traceExtent );
		if( hitActor == none )
		{
			hitLocation = traceEnd;
		}

		// The bounding box's location is not the same as the actors location so we need an offset.
		spawnLocation = hitLocation - itemExtentOffset;

		//DrawDebugLine( traceStart, traceEnd, 255, 255, 0, true );
		//DrawDebugSphere( hitLocation, 10.0f, 16, 255, 255, 0, true );
		//DrawDebugBox( spawnLocation, vect( 10, 10, 10 ), 255, 255, 0, true );
		//DrawDebugBox( hitLocation, traceExtent, 255, 255, 255, true );
	}
	else
	{
		`Log( "GGInventory failed to find spawn point for item actor " $ itemActor );
	}

	return spawnLocation;
}

DefaultProperties
{

}