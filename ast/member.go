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
	"fmt"

	"github.com/mschoch/dparval"
)

// ****************************************************************************
// DOT MEMBER
// ****************************************************************************

type DotMemberOperator struct {
	Type  string     `json:"type"`
	Left  Expression `json:"left"`
	Right *Property  `json:"right"`
}

func NewDotMemberOperator(left Expression, right *Property) *DotMemberOperator {
	return &DotMemberOperator{
		Type:  "dot_member",
		Left:  left,
		Right: right,
	}
}

func (this *DotMemberOperator) Evaluate(item dparval.Value) (dparval.Value, error) {
	lv, err := this.Left.Evaluate(item)
	if err != nil {
		return nil, err
	}

	if lv.Type() == dparval.OBJECT {
		// now evaluate the property in this inner context
		return this.Right.Evaluate(lv)
	}

	return nil, &dparval.Undefined{this.Right.Path}
}

func (this *DotMemberOperator) Validate() error {
	err := this.Left.Validate()
	if err != nil {
		return err
	}
	err = this.Right.Validate()
	if err != nil {
		return err
	}
	return err
}

func (this *DotMemberOperator) String() string {
	return fmt.Sprintf("%v.%v", this.Left, this.Right)
}

func (this *DotMemberOperator) VerifyFormalNotation(aliases []string, defaultAlias string) (Expression, error) {
	// dot member only performs verification of its LHS
	// RHS is always the non-leading portion of the a.b.c form
	newleft, err := this.Left.VerifyFormalNotation(aliases, defaultAlias)
	if err != nil {
		return nil, err
	}
	if newleft != nil {
		this.Left = newleft
	}
	return nil, nil
}

// ****************************************************************************
// BRACKET MEMBER
// ****************************************************************************

type BracketMemberOperator struct {
	Type  string     `json:"type"`
	Left  Expression `json:"left"`
	Right Expression `json:"right"`
}

func NewBracketMemberOperator(left, right Expression) *BracketMemberOperator {
	return &BracketMemberOperator{
		Type:  "bracket_member",
		Left:  left,
		Right: right,
	}
}

func (this *BracketMemberOperator) Evaluate(item dparval.Value) (dparval.Value, error) {
	// evaluting RHS first is more correct in case of side-effects
	rv, err := this.Right.Evaluate(item)
	if err != nil {
		return nil, err
	}

	lv, err := this.Left.Evaluate(item)
	if err != nil {
		return nil, err
	}

	if lv.Type() == dparval.OBJECT {
		if rv.Type() == dparval.STRING {
			rval := rv.Value()
			switch rval := rval.(type) {
			case string:
				virtualProperty := NewProperty(rval)
				return virtualProperty.Evaluate(lv)
			}
		}
	} else if lv.Type() == dparval.ARRAY {
		if rv.Type() == dparval.NUMBER {
			rval := rv.Value()
			switch rval := rval.(type) {
			case float64:
				index := int(rval)
				return lv.Index(index)
			}

		}
	}

	return nil, &dparval.Undefined{}
}

func (this *BracketMemberOperator) Validate() error {
	err := this.Left.Validate()
	if err != nil {
		return err
	}
	err = this.Right.Validate()
	if err != nil {
		return err
	}
	return err
}

func (this *BracketMemberOperator) VerifyFormalNotation(aliases []string, defaultAlias string) (Expression, error) {
	newleft, err := this.Left.VerifyFormalNotation(aliases, defaultAlias)
	if err != nil {
		return nil, err
	}
	if newleft != nil {
		this.Left = newleft
	}
	newright, err := this.Right.VerifyFormalNotation(aliases, defaultAlias)
	if err != nil {
		return nil, err
	}
	if newright != nil {
		this.Right = newright
	}
	return nil, nil
}

func (this *BracketMemberOperator) String() string {
	return fmt.Sprintf("%v[%v]", this.Left, this.Right)
}
