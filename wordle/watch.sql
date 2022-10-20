SELECT if(try=0,'',format('{0}/6',try::String)), c, status, clear_text 
FROM (
	SELECT
		game_id
	    ,try
	    ,target_str
	    ,input_str
	    ,if(length(target_str)=5,splitByString('', target_str),[]) as target_arr
	    ,if(length(input_str)=5,splitByString('', input_str),[]) as input_arr
	    ,if(length(input_str)=5 AND length(target_str)=5,compare(target_arr, input_arr), []) as comp
	    ,colored(target_str,input_str) as c
		,multiIf(comp=[2,2,2,2,2] AND try<=6,'You won', comp!=[2,2,2,2,2] and try>5, 'You lost','') as status
		,if(try=0 and 0=(SELECT max(try) FROM output WHERE game_id=last_game_id()),clear('New game started. Insert your guesses into `input` table'),'') as clear_text
	FROM output 
	WHERE game_id = (SELECT max(game_id) FROM games)
	ORDER BY try
)
FORMAT TSV