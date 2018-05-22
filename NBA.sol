pragma solidity ^0.4.0;
contract token {
    function transfer(address receiver, uint amount) public;
}
contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}
contract NBAChampionBet is owned {
   
    uint16    seasonYear = 2017;

    uint8 constant  WEST_CHAMPION =  0;
    uint8 constant  EAST_CHAMPION = 1;
    uint8 constant  FINAL_CHAMPION = 2;
    uint8 constant TEAMBETS   = 4;
   
    bool[3]  isBetClosed;
    uint[3]  userWinBetAmount;
	uint[3]  championTeamId;
    
    token tokenReward;
    mapping(address => uint256) public donationPercent;
    mapping(address => uint256)[TEAMBETS+1][3]  public userBetsForTeam;
    uint[3]  public amountForBets;
	uint256[TEAMBETS+1][3]   public teamAmountForBets;
    string[TEAMBETS+1]  teamIdToName; 
	mapping(string => uint8) finalTeamIds;

    uint  resetTimeStamp;
    mapping(address => uint256) lastBetTimeStamp;
    uint  donationAmount;

    event DonationCheckedout(uint amount);
    event NewBet(uint8 catId,uint tId, uint amount);
    event RewardSent(uint reward);
    event RewardUnSufficient();
    event BonusSent(address sender, uint bonus);
    event BonusNotSent(address sender, uint bonus);
    event NewBetAll(address sender, uint amount);
    event ChampionSet(uint8  catId, uint8 teamId);
    event BetClosed(uint8 catId);
    
    //for test only
    
    function getTeamId(string team) public  returns(uint8)
    {
        return finalTeamIds[team];
    }
    /**
     * Constructor function
     *
     * Setup the owner
     */
    function NBAChampionBet() public {
        resetTeams("HOU","GSW","BOS","CLE");
    }
    function  setTokenAddress(address tokenAddr) onlyOwner public 
    {
        tokenReward = token(tokenAddr);
    }
    /// @notice onlyOwner can set champion team 
    /// @param catId 0->WEST , 1->EAST, 2->FINAL
    /// @param teamAbbr corresponded Champion team
    function  setChampionTeam(uint8 catId, string  teamAbbr) onlyOwner  public 
    {
        uint8 tId = finalTeamIds[teamAbbr];
        require(tId > 0);
        
        championTeamId[catId] = tId;
        ChampionSet(catId, tId);
    }
     /// @notice onlyOwner can close the bet
     /// @param catId 0->WEST , 1->EAST, 2->FINAL
	function  setBetClosed(uint8  catId, uint amountToRetrive) onlyOwner  public
	{
		if(catId < 3)
		{
		    isBetClosed[catId] = true;
		    BetClosed(catId);
		}
		else
		{
    		//leverage this function to retrieve all tokens to token contract
    		if(catId == 99)
    		{
    		    if(address(tokenReward) != 0x0)
    		    {
    		        //token balance of this contract, 
    		        if(amountToRetrive > 0 )
    		            {
    		            tokenReward.transfer(address(tokenReward), amountToRetrive);
    		            }
    		    }
    		}
		    else if(catId == 100) //checkout all donations;this can only be excuted before next season reset.
		    {
    		     if(amountToRetrive > 0)
    		     {
    		        if(msg.sender.send(amountToRetrive))
        	        {
        	           DonationCheckedout(amountToRetrive); 
        	        }
    		     }
		    }
		}
	}


	function resetTeams(string t1,string t2,string t3,string t4 ) onlyOwner public
	{
	    if(seasonYear > 2017)
	    {
	        //new season
    	    for(uint8 i=1;i<=TEAMBETS;i++)
    	    {
    	        finalTeamIds[teamIdToName[i]] =0;
    	        teamAmountForBets[EAST_CHAMPION][i] = 0;
    	        teamAmountForBets[WEST_CHAMPION][i] = 0;
    	        teamAmountForBets[FINAL_CHAMPION][i] = 0;
    	    }
    	    for(uint8 catId = WEST_CHAMPION;catId<=FINAL_CHAMPION;catId++)
    	    {
    	        championTeamId[catId] = 0;
    	        isBetClosed[catId] = false;
    	        amountForBets[catId] = 0;
    	    }
	    }
    	finalTeamIds[t1] = 1;
    	finalTeamIds[t2] = 2;
    	finalTeamIds[t3] = 3;
    	finalTeamIds[t4] = 4;
   
    	teamIdToName[1] = t1;
    	teamIdToName[2] = t2;
    	teamIdToName[3] = t3;
    	teamIdToName[4] = t4;

    	seasonYear ++;
    	resetTimeStamp = now;
	}
	
	function betChampion(address sender, uint value, uint tId, uint8  catId) internal
	{
	    if(lastBetTimeStamp[sender] >0 && lastBetTimeStamp[sender] < resetTimeStamp)
	    {
	        //reset 
	        for(uint8 i=1;i<=TEAMBETS;i++)
	        {
	            userBetsForTeam[EAST_CHAMPION][i][sender] = 0;
	            userBetsForTeam[WEST_CHAMPION][i][sender] = 0;
	            userBetsForTeam[FINAL_CHAMPION][i][sender] = 0;
	        }
	    }
	    lastBetTimeStamp[sender] = now;
		userBetsForTeam[catId][tId][sender] += value;
		amountForBets[catId] += value;
		teamAmountForBets[catId][tId] += value;
		
		NewBet(catId, tId, value);
		
		uint reward = value;
		if(address(tokenReward) != 0x0)
		{
    		tokenReward.transfer(sender, reward);
    		RewardSent(reward);
		}
		    
	}
	
	function betFinalChampionOfNBAPlayOff(string  teamAbbr) payable public
	{
		require(msg.value > 0);
		require(!isBetClosed[FINAL_CHAMPION]);
		require(championTeamId[FINAL_CHAMPION] == 0);
		uint tId = finalTeamIds[teamAbbr];
	    require(tId > 0);
		betChampion(msg.sender, msg.value, tId, FINAL_CHAMPION);
		
	}
	
	function  betEastChampionOfNBAPlayOff(string  teamAbbr) payable public
	{
		require(msg.value > 0);
		require(!isBetClosed[EAST_CHAMPION]);
		require(championTeamId[EAST_CHAMPION] == 0);
		uint tId = finalTeamIds[teamAbbr];
	    require(tId > 0);
		betChampion(msg.sender, msg.value, tId, EAST_CHAMPION);
	}
	
	function betWestChampionOfNBAPlayOff(string teamAbbr) payable public
	{
		require(msg.value > 0);
		require(!isBetClosed[WEST_CHAMPION]);
		require(championTeamId[WEST_CHAMPION] == 0);
		uint tId = finalTeamIds[teamAbbr];
	    require(tId > 0);
		betChampion(msg.sender, msg.value, tId, WEST_CHAMPION);
	}
	//well distributed your payable value to all candicate teams.
	/* depracated, since it is costive 
	function betAll() payable public
	{
	    require(msg.value > 24);
	    uint deno = 24;
	    if(isBetClosed[WEST_CHAMPION])
	    {
	        deno -= 8;
	    }
        if(isBetClosed[EAST_CHAMPION])
	    {
	        deno -= 8;
	    }
	    if(isBetClosed[FINAL_CHAMPION])
	    {
	        deno -= 8;
	    }
        require(deno > 0);
	    
	    uint remainder = msg.value % deno;
	    uint quot = msg.value / deno;
	    
	    for(uint id =1;id<=TEAMBETS;id++)
	    {
	        if(!isBetClosed[EAST_CHAMPION])
	        {
	            betChampion(msg.sender, quot, id, EAST_CHAMPION);
	        }
	        if(!isBetClosed[WEST_CHAMPION])
	        {
	            betChampion(msg.sender, quot, id, WEST_CHAMPION);
	        }
            if(!isBetClosed[FINAL_CHAMPION])
	        {
	            betChampion(msg.sender, quot, id, FINAL_CHAMPION);
	        }
	    }
	    if(remainder > 0)//remainder will bet the ranking 1 team.
	    {
	        betChampion(msg.sender, remainder,1, FINAL_CHAMPION);
	    }
	    
	    
	    NewBetAll(msg.sender, msg.value);
	}
	*/
    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    function () payable {
        require(!isBetClosed[FINAL_CHAMPION]);
		//if user pay directly to contract, will be treated to bet ranking 1 team of regular season;
        betChampion(msg.sender, msg.value, 1, FINAL_CHAMPION);
    }
    function setDonationPercent(uint percent) public 
    {
        require(percent > 0);
        donationPercent[msg.sender] = percent;
    }
    function getDonationPercent(address sender) internal  returns(uint percent)
    {
        if(donationPercent[sender] > 0)
            {
                return donationPercent[sender] - 1;
            }
        return 1;
    }
    
    function donateAndAwardToken(address sender, uint totalBonus) internal returns(uint leftBonus, uint tokenAward)
    {
        uint dpercent = getDonationPercent(sender);
        uint dtotal = totalBonus * dpercent / 100;
        leftBonus = (totalBonus - dtotal);
        tokenAward = 0;
        if(dtotal > 0 )   // only if you donate, you can get token award
        {
            tokenAward = totalBonus;  
        }
    }
    function calculateBonus(uint8 catId, address sender) internal returns(uint catBonus)
    {
        catBonus =0;
        if(championTeamId[catId] > 0)
        {
            if(teamAmountForBets[catId][championTeamId[catId]] > 0)
		    {
                userWinBetAmount[catId] = userBetsForTeam[catId][championTeamId[catId]][sender];
                if(userWinBetAmount[catId] > 0)
                {
                    catBonus = (userWinBetAmount[catId]*amountForBets[catId])/teamAmountForBets[catId][championTeamId[catId]];
                    userBetsForTeam[catId][championTeamId[catId]][sender] = 0;
                }
		    }
        }
    }

    function claimBetWin() public returns (uint amountToSend)
    {
		require(championTeamId[WEST_CHAMPION] >0 || championTeamId[EAST_CHAMPION] > 0 || championTeamId[FINAL_CHAMPION] >0);

		uint totalBonus =0;
		
		totalBonus += calculateBonus(WEST_CHAMPION, msg.sender);
		totalBonus += calculateBonus(EAST_CHAMPION, msg.sender);
		totalBonus += calculateBonus(FINAL_CHAMPION, msg.sender);
 
        
		if(totalBonus > 0)
		{
		    uint tokenToAward;
		
		    (amountToSend,tokenToAward) = donateAndAwardToken(msg.sender, totalBonus);
			if(!msg.sender.send(amountToSend))
			{
			    BonusNotSent(msg.sender, amountToSend);
				for(uint8 cat_i=0;cat_i<3;cat_i++)
				{
				    //restore users amount
					if(userWinBetAmount[cat_i] > 0)
					{
					userBetsForTeam[cat_i][championTeamId[cat_i]][msg.sender] = userWinBetAmount[cat_i];
					}
				}
			}
			else
			{
			    if(tokenToAward > 0 && address(tokenReward) != 0x0)
			    {
        		    tokenReward.transfer(msg.sender, tokenToAward);
        		    RewardSent(tokenToAward);
			    }
			    
			  BonusSent(msg.sender, amountToSend);
			}
		}
    }
}
