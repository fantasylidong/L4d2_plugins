<?php
/**
 * This file is part of GameQ.
 *
 * GameQ is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * GameQ is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * $Id: openttd.php,v 1.1 2009/10/24 18:45:16 evilpie Exp $  
 */
 
 
require_once GAMEQ_BASE . 'Protocol.php';

/**
 * OpenTTD Protocol, direct port from udp.cpp source from the game
 *
 * @author         Tom Schuster <evilpie@users.sf.net>
 * @version        $Revision: 1.1 $
 */
 
 class GameQ_Protocol_openttd extends GameQ_Protocol
 {
	public function status ()
	{
		$this->p->readInt16(); # packet size
		$this->p->readInt8(); # packet type
		
		$protocol_version = $this->p->readInt8();
		$this->r->add('protocol_version', $protocol_version);
		switch ($protocol_version)
		{
			case 4:
				$num_grfs = $this->p->readInt8(); #number of grfs
				$this->r->add('num_grfs', $num_grfs);
				$this->p->skip ($num_grfs * 20); #skip id and md5 hash
			case 3:
				$this->r->add('game_date', $this->p->readInt32());
				$this->r->add('start_date', $this->p->readInt32());
			case 2:
				$this->r->add('companies_max', $this->p->readInt8());
				$this->r->add('companies_on', $this->p->readInt8());
				$this->r->add('spectators_max', $this->p->readInt8());
			case 1:
				$this->r->add('hostname', $this->p->readString());
				$this->r->add('version', $this->p->readString());
				$this->r->add('language', $this->p->readInt8());
				$this->r->add('password', $this->p->readInt8());
				$this->r->add('max_clients', $this->p->readInt8());
				$this->r->add('clients', $this->p->readInt8());
				$this->r->add('spectators', $this->p->readInt8());
				if ($protocol_version < 3)
				{
					$days = ( 365 * 1920 + 1920 / 4 - 1920 / 100 + 1920 / 400 );
					$this->r->add('game_date', $this->p->readInt16() + $days);
					$this->r->add('start_date', $this->p->readInt16() + $days);
				}
				$this->r->add('map', $this->p->readString());
				$this->r->add('map_width', $this->p->readInt16());
				$this->r->add('map_height', $this->p->readInt16());
				$this->r->add('map_type', $this->p->readInt8());
				$this->r->add('dedicated', $this->p->readInt8());
		}
	}
 }