//  Copyright (c) 2013 Couchbase, Inc.
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

package ast

import (
	"encoding/base64"

	"github.com/couchbaselabs/dparval"
)

type FunctionCallMeta struct {
	FunctionCall
}

func NewFunctionCallMeta(operands FunctionArgExpressionList) FunctionCallExpression {
	return &FunctionCallMeta{
		FunctionCall{
			Type:     "function",
			Name:     "META",
			Operands: operands,
			minArgs:  1,
			maxArgs:  1,
		},
	}
}

func (this *FunctionCallMeta) Evaluate(item *dparval.Value) (*dparval.Value, error) {

	av, err := this.Operands[0].Expr.Evaluate(item)
	if err != nil {
		return nil, err
	}

	meta := av.GetAttachment("meta")
	return dparval.NewValue(meta), nil
}

func (this *FunctionCallMeta) Accept(ev ExpressionVisitor) (Expression, error) {
	return ev.Visit(this)
}

type FunctionCallValue struct {
	FunctionCall
}

func NewFunctionCallValue(operands FunctionArgExpressionList) FunctionCallExpression {
	return &FunctionCallValue{
		FunctionCall{
			Type:     "function",
			Name:     "VALUE",
			Operands: operands,
			minArgs:  1,
			maxArgs:  1,
		},
	}
}

func (this *FunctionCallValue) Evaluate(item *dparval.Value) (*dparval.Value, error) {
	// first evaluate the argument
	av, err := this.Operands[0].Expr.Evaluate(item)
	if err != nil {
		return nil, err
	}
	return av, nil
}

func (this *FunctionCallValue) Accept(ev ExpressionVisitor) (Expression, error) {
	return ev.Visit(this)
}

type FunctionCallBase64Value struct {
	FunctionCall
}

func NewFunctionCallBase64Value(operands FunctionArgExpressionList) FunctionCallExpression {
	return &FunctionCallBase64Value{
		FunctionCall{
			Type:     "function",
			Name:     "BASE64_VALUE",
			Operands: operands,
			minArgs:  1,
			maxArgs:  1,
		},
	}
}

func (this *FunctionCallBase64Value) Evaluate(item *dparval.Value) (*dparval.Value, error) {
	// first evaluate the argument
	av, err := this.Operands[0].Expr.Evaluate(item)
	if err != nil {
		return nil, err
	}

	rawBytes := av.Bytes()
	base64Str := base64.StdEncoding.EncodeToString(rawBytes)

	return dparval.NewValue(base64Str), nil
}

func (this *FunctionCallBase64Value) Accept(ev ExpressionVisitor) (Expression, error) {
	return ev.Visit(this)
}
