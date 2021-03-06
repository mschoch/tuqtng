%{
package goyacc
import "github.com/couchbaselabs/clog"
import "github.com/couchbaselabs/tuqtng/parser"
import "github.com/couchbaselabs/tuqtng/ast"

func logDebugGrammar(format string, v ...interface{}) {
    clog.To(parser.PARSER_CHANNEL, format, v...)
}
%}

%union { 
s string 
n int
f float64}

%token EXPLAIN
%token CREATE DROP VIEW INDEX ON USING
%token DISTINCT UNIQUE
%token SELECT AS FROM WHERE
%token ORDER BY ASC DESC
%token LIMIT OFFSET
%token GROUP BY HAVING
%token LBRACE RBRACE LBRACKET RBRACKET
%token COMMA COLON
%token TRUE FALSE NULL
%token INT NUMBER IDENTIFIER STRING
%token PLUS MINUS MULT DIV
%token CONCAT
%token AND OR NOT
%token EQ NE GT GTE LT LTE
%token LPAREN RPAREN
%token LIKE IS VALUED MISSING
%token DOT
%token CASE WHEN THEN ELSE END
%token ANY ALL OVER FIRST ARRAY IN
%left OR
%left AND 
%left DOT LBRACKET
%left EQ LT LTE GT GTE NE LIKE
%left PLUS MINUS
%left MULT DIV MOD CONCAT
%left IS
%right NOT

%%

input: 
stmt {
	logDebugGrammar("INPUT")
}
|
EXPLAIN stmt {
	logDebugGrammar("INPUT - EXPLAIN")
	parsingStatement.SetExplainOnly(true)
}

stmt:
select_stmt { 
	logDebugGrammar("STMT - SELECT")
}
|
create_index_stmt {
	logDebugGrammar("STMT - CREATE INDEX")
}
|
drop_index_stmt {
	logDebugGrammar("STMT - DROP INDEX")
}
;

// CREATE INDEX STATEMENT
create_index_stmt:
CREATE INDEX IDENTIFIER ON IDENTIFIER LPAREN expression_list RPAREN {
	on := parsingStack.Pop().(ast.ExpressionList)
	bucket := $5.s
	name := $3.s
	createIndexStmt := ast.NewCreateIndexStatement()
	createIndexStmt.On = on
	createIndexStmt.Bucket = bucket
	createIndexStmt.Name = name
	parsingStatement = createIndexStmt
}
|
CREATE INDEX IDENTIFIER ON COLON IDENTIFIER DOT IDENTIFIER LPAREN expression_list RPAREN {
	on := parsingStack.Pop().(ast.ExpressionList)
	bucket := $8.s
	pool := $6.s
	name := $3.s
	createIndexStmt := ast.NewCreateIndexStatement()
	createIndexStmt.On = on
	createIndexStmt.Pool = pool
	createIndexStmt.Bucket = bucket
	createIndexStmt.Name = name
	parsingStatement = createIndexStmt
}
|
CREATE INDEX IDENTIFIER ON IDENTIFIER LPAREN expression_list RPAREN USING view_using {
	method := parsingStack.Pop().(string)
	on := parsingStack.Pop().(ast.ExpressionList)
	bucket := $5.s
	name := $3.s
	createIndexStmt := ast.NewCreateIndexStatement()
	createIndexStmt.On = on
	createIndexStmt.Bucket = bucket
	createIndexStmt.Name = name
	createIndexStmt.Method = method
	parsingStatement = createIndexStmt
}
|
CREATE INDEX IDENTIFIER ON COLON IDENTIFIER DOT IDENTIFIER LPAREN expression_list RPAREN USING view_using {
	method := parsingStack.Pop().(string)
	on := parsingStack.Pop().(ast.ExpressionList)
	bucket := $8.s
	pool := $6.s
	name := $3.s
	createIndexStmt := ast.NewCreateIndexStatement()
	createIndexStmt.On = on
	createIndexStmt.Pool = pool
	createIndexStmt.Bucket = bucket
	createIndexStmt.Name = name
	createIndexStmt.Method = method
	parsingStatement = createIndexStmt
}
;

view_using:
VIEW {
	parsingStack.Push("view")
}
|
IDENTIFIER {
	parsingStack.Push($1.s)
}

// DROP INDEX
drop_index_stmt:
DROP INDEX IDENTIFIER DOT IDENTIFIER {
	bucket := $3.s
	name := $5.s
	dropIndexStmt := ast.NewDropIndexStatement()
	dropIndexStmt.Bucket = bucket
	dropIndexStmt.Name = name
	parsingStatement = dropIndexStmt
}
|
DROP INDEX COLON IDENTIFIER DOT IDENTIFIER DOT IDENTIFIER {
	bucket := $6.s
	pool := $4.s
	name := $8.s
	dropIndexStmt := ast.NewDropIndexStatement()
	dropIndexStmt.Pool = pool
	dropIndexStmt.Bucket = bucket
	dropIndexStmt.Name = name
	parsingStatement = dropIndexStmt
}
;

// SELECT STATEMENT
select_stmt:
select_compound  {
	logDebugGrammar("SELECT_STMT")
}
;

select_compound:    
select_core select_order select_limit_offset {
	// future extensibility for comining queries with UNION, etc
	logDebugGrammar("SELECT_COMPOUND") 
}
;

select_core:    
select_select select_from select_where select_group_having {
	logDebugGrammar("SELECT_CORE")
}
|
select_from_required select_where select_group_having select_select{
	logDebugGrammar("SELECT_CORE")
}
;

select_group_having:
/* empty */ {
}
|
GROUP BY expression_list having {
	group_by := parsingStack.Pop().(ast.ExpressionList)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.GroupBy = group_by
	default:
		logDebugGrammar("This statement does not support GROUP BY")
	}
}
;

having:
/* empty */ {
}
|
HAVING expression {
	logDebugGrammar("SELECT HAVING - EXPR")
	having_part := parsingStack.Pop().(ast.Expression)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Having = having_part
	default:
		logDebugGrammar("This statement does not support HAVING")
	}
}
;

select_select:  
select_select_head select_select_qualifier select_select_tail {
	logDebugGrammar("SELECT_SELECT")
}
;

select_select_head:  
SELECT { 
	logDebugGrammar("SELECT_SELECT_HEAD")
}
;

select_select_qualifier:
/* empty */ {
}
|
DISTINCT {
	logDebugGrammar("SELECT_SELECT_QUALIFIER DISTINCT")
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Distinct = true
	default:
		logDebugGrammar("This statement does not support WHERE")
	}
}
|
UNIQUE {
	logDebugGrammar("SELECT_SELECT_QUALIFIER UNIQUE")
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Distinct = true
	default:
		logDebugGrammar("This statement does not support WHERE")
	}
}
;

select_select_tail:		
result_list { 
	logDebugGrammar("SELECT SELECT TAIL - EXPR")
	result_expr_list := parsingStack.Pop().(ast.ResultExpressionList)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Select = result_expr_list
	default:
		logDebugGrammar("This statement does not support WHERE")
	}

}
;

result_list:
result_single {
	result_expr := parsingStack.Pop().(*ast.ResultExpression)
	parsingStack.Push(ast.ResultExpressionList{result_expr})
}
|
result_single COMMA result_list {
	result_expr_list := parsingStack.Pop().(ast.ResultExpressionList)
	result_expr := parsingStack.Pop().(*ast.ResultExpression)
	// list items pushed onto the stack end up in reverse order
	// this prepends items in the list to restore order
	new_list := ast.ResultExpressionList{result_expr}
	for _, v := range result_expr_list {
		new_list = append(new_list, v)
	}
	parsingStack.Push(new_list)
};

result_single:
dotted_path_star {
	logDebugGrammar("RESULT STAR")
}
|
expression { 
	logDebugGrammar("RESULT EXPR")
	expr_part := parsingStack.Pop().(ast.Expression)
	result_expr := ast.NewResultExpression(expr_part)
	parsingStack.Push(result_expr)
}
|
expression AS IDENTIFIER { 
	logDebugGrammar("SORT EXPR ASC")
	expr_part := parsingStack.Pop().(ast.Expression)
	result_expr := ast.NewResultExpressionWithAlias(expr_part, $3.s)
	parsingStack.Push(result_expr)
}
;

dotted_path_star:
MULT {
	logDebugGrammar("STAR")
	result_expr := ast.NewStarResultExpression()
	parsingStack.Push(result_expr)
}
|
expr DOT MULT {
	logDebugGrammar("PATH DOT STAR")
	expr_part := parsingStack.Pop().(ast.Expression)
	result_expr := ast.NewDotStarResultExpression(expr_part)
	parsingStack.Push(result_expr)
}
;

select_from:
/* empty */ {
	logDebugGrammar("SELECT FROM - EMPTY")
}
|
FROM data_source_over {
	logDebugGrammar("SELECT FROM - DATASOURCE")
	from := parsingStack.Pop().(*ast.From)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.From = from
	default:
		logDebugGrammar("This statement does not support FROM")
	}
}
|
FROM COLON IDENTIFIER DOT data_source_over {
	logDebugGrammar("SELECT FROM - DATASOURCE WITH POOL")
	from := parsingStack.Pop().(*ast.From)
	from.Pool = $3.s
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.From = from
	default:
		logDebugGrammar("This statement does not support FROM")
	}
}
;

select_from_required:
FROM data_source_over {
	logDebugGrammar("SELECT FROM - DATASOURCE")
	from := parsingStack.Pop().(*ast.From)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.From = from
	default:
		logDebugGrammar("This statement does not support FROM")
	}
}
|
FROM COLON IDENTIFIER DOT data_source_over {
	logDebugGrammar("SELECT FROM - DATASOURCE WITH POOL")
	from := parsingStack.Pop().(*ast.From)
	from.Pool = $3.s
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.From = from
	default:
		logDebugGrammar("This statement does not support FROM")
	}
}
;

data_source_over:
data_source {
	logDebugGrammar("FROM DATASOURCE WITHOUT OVER")
}
|
data_source over_source {
	logDebugGrammar("FROM DATASOURCE WITH OVER")
	rest := parsingStack.Pop().(*ast.From)
	last := parsingStack.Pop().(*ast.From)
	last.Over = rest
	parsingStack.Push(last)
}
;

over_source:
OVER IDENTIFIER IN path {
	logDebugGrammar("OVER IN")
	proj := parsingStack.Pop().(ast.Expression)
	parsingStack.Push(&ast.From{Projection: proj, As: $2.s})
}
|
OVER IDENTIFIER IN path over_source {
	logDebugGrammar("OVER IN nested")
	rest := parsingStack.Pop().(*ast.From)
	proj := parsingStack.Pop().(ast.Expression)
	parsingStack.Push(&ast.From{Projection: proj, As: $2.s, Over:rest})
}
;

data_source:
path {
	logDebugGrammar("FROM DATASOURCE")
	proj := parsingStack.Pop().(ast.Expression)
	parsingStack.Push(&ast.From{Projection: proj})
}
|
path AS IDENTIFIER {
    // fixme support over as
	logDebugGrammar("FROM DATASOURCE AS")
	proj := parsingStack.Pop().(ast.Expression)
	parsingStack.Push(&ast.From{Projection: proj, As: $3.s})
}

select_where:   
/* empty */ { 
	logDebugGrammar("SELECT WHERE - EMPTY")
}
|
WHERE expression {
	logDebugGrammar("SELECT WHERE - EXPR")
	where_part := parsingStack.Pop().(ast.Expression)
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Where = where_part
	default:
		logDebugGrammar("This statement does not support WHERE")
	}
};

select_order:   
/* empty */
|
ORDER BY sorting_list {
	
}
;

sorting_list:
sorting_single {
	
}
|
sorting_single COMMA sorting_list {
	
};

sorting_single:
expression { 
	logDebugGrammar("SORT EXPR")
	expr := parsingStack.Pop()
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.OrderBy = append(parsingStatement.OrderBy, ast.NewSortExpression(expr.(ast.Expression), true))
	default:
		logDebugGrammar("This statement does not support ORDER BY")
	}
}
|
expression ASC { 
	logDebugGrammar("SORT EXPR ASC")
	expr := parsingStack.Pop()
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.OrderBy = append(parsingStatement.OrderBy, ast.NewSortExpression(expr.(ast.Expression), true))
	default:
		logDebugGrammar("This statement does not support ORDER BY")
	}
}
|
expression DESC { 
	logDebugGrammar("SORT EXPR DESC")
	expr := parsingStack.Pop()
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.OrderBy = append(parsingStatement.OrderBy, ast.NewSortExpression(expr.(ast.Expression), false))
	default:
		logDebugGrammar("This statement does not support ORDER BY")
	}
};

select_limit_offset:
/* empty */ {
	
}
|
select_limit {
	
}
|
select_limit select_offset {
	
}
;

select_limit:
LIMIT INT {
	logDebugGrammar("LIMIT %d", $2.n)
	if $2.n < 0 {
		panic("LIMIT cannot be negative")
	}
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Limit = $2.n
	default:
		logDebugGrammar("This statement does not support LIMIT")
	}
};

select_offset:
OFFSET INT { 
	logDebugGrammar("OFFSET %d", $2.n)
	if $2.n < 0 {
		panic("OFFSET cannot be negative")
	}
	switch parsingStatement := parsingStatement.(type) {
	case *ast.SelectStatement:
		parsingStatement.Offset = $2.n
	default:
		logDebugGrammar("This statement does not support OFFSET")
	}
};

//EXPRESSION

expression:
expr {
	logDebugGrammar("EXPRESSION")
};

expr:
expr PLUS expr {
	logDebugGrammar("EXPR - PLUS")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewPlusOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr MINUS expr {
	logDebugGrammar("EXPR - MINUS")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewSubtractOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr MULT expr {
	logDebugGrammar("EXPR - MULT")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewMultiplyOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr DIV expr {
	logDebugGrammar("EXPR - DIV")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewDivideOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr MOD expr {
	logDebugGrammar("EXPR - MOD")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewModuloOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr CONCAT expr {
	logDebugGrammar("EXPR - CONCAT")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewStringConcatenateOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr AND expr {
	logDebugGrammar("EXPR - AND")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewAndOperator(ast.ExpressionList{left.(ast.Expression), right.(ast.Expression)})
	parsingStack.Push(thisExpression)
}
|
expr OR expr {
	logDebugGrammar("EXPR - OR")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewOrOperator(ast.ExpressionList{left.(ast.Expression), right.(ast.Expression)})
	parsingStack.Push(thisExpression)
}
|
expr EQ expr {
	logDebugGrammar("EXPR - EQ")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewEqualToOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr LT expr {
	logDebugGrammar("EXPR - LT")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewLessThanOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr LTE expr {
	logDebugGrammar("EXPR - LTE")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewLessThanOrEqualOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr GT expr {
	logDebugGrammar("EXPR - GT")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewGreaterThanOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr GTE expr {
	logDebugGrammar("EXPR - GTE")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewGreaterThanOrEqualOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr NE expr {
	logDebugGrammar("EXPR - NE")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewNotEqualToOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr LIKE expr {
	logDebugGrammar("EXPR - LIKE")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewLikeOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr NOT LIKE expr {
	logDebugGrammar("EXPR - NOT LIKE")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewNotLikeOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr DOT IDENTIFIER {
	logDebugGrammar("EXPR DOT MEMBER")
	right := ast.NewProperty($3.s) 
	left := parsingStack.Pop()
	thisExpression := ast.NewDotMemberOperator(left.(ast.Expression), right) 
	parsingStack.Push(thisExpression)
}
|
expr LBRACKET expr RBRACKET {
	logDebugGrammar("EXPR BRACKET MEMBER")
	right := parsingStack.Pop()
	left := parsingStack.Pop()
	thisExpression := ast.NewBracketMemberOperator(left.(ast.Expression), right.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS NULL {
	logDebugGrammar("SUFFIX_EXPR IS NULL")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsNullOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS NOT NULL {
	logDebugGrammar("SUFFIX_EXPR IS NOT NULL")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsNotNullOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS MISSING {
	logDebugGrammar("SUFFIX_EXPR IS MISSING")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsMissingOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS NOT MISSING {
	logDebugGrammar("SUFFIX_EXPR IS NOT MISSING")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsNotMissingOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS VALUED {
	logDebugGrammar("SUFFIX_EXPR IS VALUED")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsValuedOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
expr IS NOT VALUED {
	logDebugGrammar("SUFFIX_EXPR IS NOT VALUED")
	operand := parsingStack.Pop()
	thisExpression := ast.NewIsNotValuedOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
prefix_expr {
	
}
;

prefix_expr: 
NOT prefix_expr {
	logDebugGrammar("EXPR - NOT")
	operand := parsingStack.Pop()
	thisExpression := ast.NewNotOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
MINUS prefix_expr {
	logDebugGrammar("EXPR - CHANGE SIGN")
	operand := parsingStack.Pop()
	thisExpression := ast.NewChangeSignOperator(operand.(ast.Expression)) 
	parsingStack.Push(thisExpression)
}
|
suffix_expr {
	
};

suffix_expr: 
atom {
	logDebugGrammar("SUFFIX_EXPR")
}
;

atom:
IDENTIFIER {
	logDebugGrammar("IDENTIFIER - %s", $1.s)
	thisExpression := ast.NewProperty($1.s) 
	parsingStack.Push(thisExpression) 
}
|
literal_value {
	logDebugGrammar("LITERAL")
}
|
LPAREN expression RPAREN {
	logDebugGrammar("NESTED EXPR")
}
|
CASE WHEN then_list else_expr END {
	logDebugGrammar("CASE WHEN THEN ELSE END")
	cwtee := ast.NewCaseOperator()
	topStack := parsingStack.Pop()
	switch topStack := topStack.(type) {
	case ast.Expression:
		cwtee.Else = topStack
		// now look for whenthens
		nextStack := parsingStack.Pop().([]*ast.WhenThen)
		cwtee.WhenThens = nextStack
	case []*ast.WhenThen:
		// no else
		cwtee.WhenThens = topStack
	}
	parsingStack.Push(cwtee)
}
|
ANY expr OVER IDENTIFIER IN expr END {
	logDebugGrammar("ANY OVER")
	sub := parsingStack.Pop().(ast.Expression)
	condition := parsingStack.Pop().(ast.Expression)
	collectionAny := ast.NewCollectionAnyOperator(condition, sub, $4.s)
	parsingStack.Push(collectionAny)
}
|
ALL expr OVER IDENTIFIER IN expr END {
	logDebugGrammar("ALL OVER")
	sub := parsingStack.Pop().(ast.Expression)
	condition := parsingStack.Pop().(ast.Expression)
	collectionAny := ast.NewCollectionAllOperator(condition, sub, $4.s)
	parsingStack.Push(collectionAny)
}
|
FIRST expr OVER IDENTIFIER IN expr WHEN expr END {
	logDebugGrammar("FIRST OVER")
	condition := parsingStack.Pop().(ast.Expression)
	sub := parsingStack.Pop().(ast.Expression)
	output := parsingStack.Pop().(ast.Expression)
	collectionFirst := ast.NewCollectionFirstOperator(condition, sub, $4.s, output)
	parsingStack.Push(collectionFirst)
}
|
FIRST expr OVER IDENTIFIER IN expr END {
	logDebugGrammar("FIRST OVER")
	sub := parsingStack.Pop().(ast.Expression)
	output := parsingStack.Pop().(ast.Expression)
	collectionFirst := ast.NewCollectionFirstOperator(nil, sub, $4.s, output)
	parsingStack.Push(collectionFirst)
}
|
ARRAY expr OVER IDENTIFIER IN expr WHEN expr END {
	logDebugGrammar("ARRAY OVER WHEN")
	condition := parsingStack.Pop().(ast.Expression)
	sub := parsingStack.Pop().(ast.Expression)
	output := parsingStack.Pop().(ast.Expression)
	collectionArray := ast.NewCollectionArrayOperator(condition, sub, $4.s, output)
	parsingStack.Push(collectionArray)
}
|
ARRAY expr OVER IDENTIFIER IN expr END {
	logDebugGrammar("ARRAY OVER")
	sub := parsingStack.Pop().(ast.Expression)
	output := parsingStack.Pop().(ast.Expression)
	collectionArray := ast.NewCollectionArrayOperator(nil, sub, $4.s, output)
	parsingStack.Push(collectionArray)
}
|
IDENTIFIER LPAREN RPAREN {
	logDebugGrammar("FUNCTION EXPR NOPARAM")
	thisExpression := ast.NewFunctionCall($1.s, ast.FunctionArgExpressionList{})
	parsingStack.Push(thisExpression)
}
|
IDENTIFIER LPAREN function_arg_list RPAREN {
	logDebugGrammar("FUNCTION EXPR PARAM")
	funarg_exp_list := parsingStack.Pop().(ast.FunctionArgExpressionList)
	thisExpression := ast.NewFunctionCall($1.s, funarg_exp_list)
	parsingStack.Push(thisExpression)
}
|
IDENTIFIER LPAREN DISTINCT function_arg_list RPAREN {
	logDebugGrammar("FUNCTION DISTINCT EXPR PARAM")
	funarg_exp_list := parsingStack.Pop().(ast.FunctionArgExpressionList)
	function := ast.NewFunctionCall($1.s, funarg_exp_list)
	function.SetDistinct(true)
	parsingStack.Push(function)
}
|
IDENTIFIER LPAREN UNIQUE function_arg_list RPAREN {
	logDebugGrammar("FUNCTION EXPR PARAM")
	funarg_exp_list := parsingStack.Pop().(ast.FunctionArgExpressionList)
	thisExpression := ast.NewFunctionCall($1.s, funarg_exp_list)
	parsingStack.Push(thisExpression)
}
;

then_list:
expr THEN expr {
	logDebugGrammar("THEN_LIST - SINGLE")
	when_then_list := make([]*ast.WhenThen, 0)
	when_then := ast.WhenThen{Then: parsingStack.Pop().(ast.Expression), When: parsingStack.Pop().(ast.Expression)}
	when_then_list = append(when_then_list, &when_then)
	parsingStack.Push(when_then_list)
}
|
expr THEN expr WHEN then_list {
	logDebugGrammar("THEN_LIST - COMPOUND")
	rest := parsingStack.Pop().([]*ast.WhenThen)
	last := ast.WhenThen{Then: parsingStack.Pop().(ast.Expression), When: parsingStack.Pop().(ast.Expression)}
	new_list := make([]*ast.WhenThen, 0, len(rest) + 1)
	new_list = append(new_list, &last)
	for _, v := range rest {
		new_list = append(new_list, v)
	}
	parsingStack.Push(new_list)
}
;

else_expr:
/* empty */ {
	logDebugGrammar("ELSE - EMPTY")
}
|
ELSE expr {
	logDebugGrammar("ELSE - EXPR")
}
;

path:
IDENTIFIER {
	logDebugGrammar("PATH - %v", $1.s)
	thisExpression := ast.NewProperty($1.s) 
	parsingStack.Push(thisExpression) 
}
|
path LBRACKET INT RBRACKET {
	logDebugGrammar("PATH BRACKET - %v[%v]", $1.s, $3.n)
	left := parsingStack.Pop()
	thisExpression := ast.NewBracketMemberOperator(left.(ast.Expression), ast.NewLiteralNumber(float64($3.n))) 
	parsingStack.Push(thisExpression)
}
|
path DOT IDENTIFIER {
	logDebugGrammar("PATH DOT PATH - $1.s")
	right := ast.NewProperty($3.s) 
	left := parsingStack.Pop()
	thisExpression := ast.NewDotMemberOperator(left.(ast.Expression), right) 
	parsingStack.Push(thisExpression)
}
;


function_arg_list:
function_arg_single {
	funarg_expr := parsingStack.Pop().(*ast.FunctionArgExpression)
	parsingStack.Push(ast.FunctionArgExpressionList{funarg_expr})
}
|
function_arg_single COMMA function_arg_list {
	funarg_expr_list := parsingStack.Pop().(ast.FunctionArgExpressionList)
	funarg_expr := parsingStack.Pop().(*ast.FunctionArgExpression)
	// list items pushed onto the stack end up in reverse order
	// this prepends items in the list to restore order
	new_list := ast.FunctionArgExpressionList{funarg_expr}
	for _, v := range funarg_expr_list {
		new_list = append(new_list, v)
	}
	parsingStack.Push(new_list)
}
;

function_arg_single:
fun_dotted_path_star {
	logDebugGrammar("FUNARG STAR")
}
|
expression {
	logDebugGrammar("FUNARG EXPR")
	expr_part := parsingStack.Pop().(ast.Expression)
	funarg_expr := ast.NewFunctionArgExpression(expr_part)
	parsingStack.Push(funarg_expr)
}
;

fun_dotted_path_star:
MULT {
	logDebugGrammar("FUNSTAR")
	funarg_expr := ast.NewStarFunctionArgExpression()
	parsingStack.Push(funarg_expr)
}
|
expr DOT MULT {
	logDebugGrammar("FUN PATH DOT STAR")
	expr_part := parsingStack.Pop().(ast.Expression)
	funarg_expr := ast.NewDotStarFunctionArgExpression(expr_part)
	parsingStack.Push(funarg_expr)
}

//JSON

literal_value:
STRING {
	logDebugGrammar("STRING %s", $1.s)
	thisExpression := ast.NewLiteralString($1.s) 
	parsingStack.Push(thisExpression)
}
|
number {
	logDebugGrammar("NUMBER")
}
|
object {
	logDebugGrammar("OBJECT")
}
|
array {
	logDebugGrammar("ARRAY")
}
|
TRUE {
	logDebugGrammar("TRUE")
	thisExpression := ast.NewLiteralBool(true) 
	parsingStack.Push(thisExpression)
}
|
FALSE {
	logDebugGrammar("FALSE")
	thisExpression := ast.NewLiteralBool(false) 
	parsingStack.Push(thisExpression)
}
|
NULL {
	logDebugGrammar("NULL")
	thisExpression := ast.NewLiteralNull()
	parsingStack.Push(thisExpression)
}
;

number:
INT {
	logDebugGrammar("NUMBER %d", $1.n)
	thisExpression := ast.NewLiteralNumber(float64($1.n))
	parsingStack.Push(thisExpression)
}
|
NUMBER {
	logDebugGrammar("NUMBER %f", $1.f)
	thisExpression := ast.NewLiteralNumber($1.f)
	parsingStack.Push(thisExpression)
}
;

object:
LBRACE RBRACE {
	logDebugGrammar("EMPTY OBJECT")
	emptyObject := ast.NewLiteralObject(map[string]ast.Expression{})
	parsingStack.Push(emptyObject)
}
|
LBRACE named_expression_list RBRACE {
	logDebugGrammar("OBJECT")
}
;

named_expression_list:
named_expression_single {
	logDebugGrammar("NAMED EXPR LIST SINGLE")
}
|
named_expression_single COMMA named_expression_list {
	logDebugGrammar("NAMED EXPR LIST COMPOUND")
	last := parsingStack.Pop().(*ast.LiteralObject)
	rest := parsingStack.Pop().(*ast.LiteralObject)
	for k,v := range last.Val {
		rest.Val[k] = v
	}
	parsingStack.Push(rest)
}
;

named_expression_single:   
STRING COLON expression {  
	logDebugGrammar("NAMED EXPR SINGLE")
	thisKey := $1.s
	thisValue := parsingStack.Pop().(ast.Expression)
	thisExpression := ast.NewLiteralObject(map[string]ast.Expression{thisKey: thisValue})
	parsingStack.Push(thisExpression) 
}
;

array:
LBRACKET RBRACKET {
	logDebugGrammar("EMPTY ARRAY")
	thisExpression := ast.NewLiteralArray(ast.ExpressionList{})
	parsingStack.Push(thisExpression)
}
|
LBRACKET expression_list RBRACKET {
	logDebugGrammar("ARRAY")
	exp_list := parsingStack.Pop().(ast.ExpressionList)
	thisExpression := ast.NewLiteralArray(exp_list)
	parsingStack.Push(thisExpression)
}
;

expression_list:
expression {
	logDebugGrammar("EXPRESSION LIST SINGLE")
	exp_list := make(ast.ExpressionList, 0)
	exp_list = append(exp_list, parsingStack.Pop().(ast.Expression))
	parsingStack.Push(exp_list)
}
|
expression COMMA expression_list { 
	logDebugGrammar("EXPRESSION LIST COMPOUND")
	rest := parsingStack.Pop().(ast.ExpressionList)
	last := parsingStack.Pop()
	new_list := make(ast.ExpressionList, 0, len(rest) + 1)
	new_list = append(new_list, last.(ast.Expression))
	for _, v := range rest {
		new_list = append(new_list, v)
	}
	parsingStack.Push(new_list)
}
;
