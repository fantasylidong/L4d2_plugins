#if defined boost_entity_inc_
    #endinput
#endif
#define boost_entity_inc_


/**
 * @brief		    	Create an explosion effect.
 *
 * @param entity    	Entity of explosion.
 * @param pos	    	The position of explosion.
 * @param particle_name	The name of explosion's particle.
 * @return 			    It will return an entity index that can be used next time.
 * @NOTE:			    Remember to kill the entity when needed.
 */
native int Entity_CreateExplosionEffect(int entity = 0, float pos[3], const char[] particle_name);

/**
 * @brief			Set an entity's model
 * @remarks			It will avoid bugs compared with sdktools::SetEntityModel
 *
 * @param entity	Entity you want to change its model
 * @param model		The path of model you want to change to. You should precache this model before use it.
 * @param prop		Entity will be used to change model
 * @return 			It will return an entity index. If you want to change the same entity's model again or restore it, please push the result into param 'prop'
 * @NOTE:			If change isnt needed any more, PLEASE use Entity_RestoreEntityModel to RELEASE RESOURCE! 
 */
native int Entity_SetEntityModel(int entity, const char[] model, int prop = -1);

/**
 * @brief			Restore an entity's model
 * @remarks			After use Entity_SetEntityModel, you should use this call to release resource
 *
 * @param entity	Entity you want to restore its model
 * @param prop		Entity will be used to change model
 * @return 			Whether entity's model is restored
 */
native bool Entity_RestoreEntityModel(int entity, int prop);




public SharedPlugin __pl_boost_entity = 
{
	name = "Boost - Entity",
	file = "boost/entity.smx",
	required = 0,
};

public void __pl_boost_entity_SetNTVOptional()
{
	MarkNativeAsOptional("Entity_CreateExplosionEffect");
    MarkNativeAsOptional("Entity_RestoreEntityModel");
    MarkNativeAsOptional("Entity_SetEntityModel");
}