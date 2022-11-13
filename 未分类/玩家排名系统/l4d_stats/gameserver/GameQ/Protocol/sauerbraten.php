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
 * $Id: sauerbraten.php,v 1.2 2008/06/25 13:50:47 tombuskens Exp $  
 */
 
 
require_once GAMEQ_BASE . 'Protocol.php';


/**
 * Sauerbraten / Cube 2 Engine protocol
 *
 * @author         Tom Buskens <t.buskens@deviation.nl>
 * @version        $Revision: 1.2 $
 */
class GameQ_Protocol_sauerbraten extends GameQ_Protocol
{
    private function getint()
    {
      $i = $this->p->readInt8();
      if ($i == 0x80)
        {
          $i = $this->p->readInt8();
          $i |= $this->p->readInt8() << 8;
        }
      else if ($i == 0x81)
        {
          $i = $this->p->readInt8();
          $i |= $this->p->readInt8() << 8;
          $i |= $this->p->readInt8() << 16;
          $i |= $this->p->readInt8() << 24;
        }

      return $i;
    }

    /*
     * status packet
     */
    public function status()
    {
        // Header
        if (!$this->p->read() == "\x00") {
            throw new GameQ_ParsingException($this->p);
        }

        // Vars
        $this->r->add('num_players',    $this->getint());
        $this->r->add('num_attributes', $this->getint());
        $this->r->add('protocol',       $this->getint());
        $this->r->add('servermode',     $this->getint());
        $this->r->add('time_remaining', $this->getint());
        $this->r->add('max_players',    $this->getint());
        $this->r->add('locked',         $this->getint());
        $this->r->add('map',            $this->p->readString());
        $this->r->add('servername',     $this->p->readString());
    }
}


?>
