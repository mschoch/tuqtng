//  Copyright (c) 2013 Couchbase, Inc.
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

package xpipeline

import (
	"github.com/couchbaselabs/tuqtng/ast"
	"github.com/couchbaselabs/tuqtng/query"
	"github.com/mschoch/dparval"
)

type DocumentJoin struct {
	Source         Operator
	Over           ast.Expression
	As             string
	itemChannel    dparval.ValueChannel
	supportChannel PipelineSupportChannel
}

func NewDocumentJoin(over ast.Expression, as string) *DocumentJoin {
	return &DocumentJoin{
		Over:           over,
		As:             as,
		itemChannel:    make(dparval.ValueChannel),
		supportChannel: make(PipelineSupportChannel),
	}
}

func (this *DocumentJoin) SetSource(source Operator) {
	this.Source = source
}

func (this *DocumentJoin) GetChannels() (dparval.ValueChannel, PipelineSupportChannel) {
	return this.itemChannel, this.supportChannel
}

func (this *DocumentJoin) Run() {
	defer close(this.itemChannel)
	defer close(this.supportChannel)

	go this.Source.Run()

	var item dparval.Value
	var obj interface{}
	sourceItemChannel, supportChannel := this.Source.GetChannels()
	ok := true
	for ok {
		select {
		case item, ok = <-sourceItemChannel:
			if ok {
				ok = this.processItem(item)
			}
		case obj, ok = <-supportChannel:
			if ok {
				switch obj := obj.(type) {
				case query.Error:
					this.supportChannel <- obj
					if obj.IsFatal() {
						return
					}
				default:
					this.supportChannel <- obj
				}
			}
		}
	}
}

func (this *DocumentJoin) processItem(item dparval.Value) bool {
	val, err := this.Over.Evaluate(item)
	if err != nil {
		switch err := err.(type) {
		case *dparval.Undefined:
			return true
		default:
			this.supportChannel <- query.NewError(err, "Internal Error")
			return false
		}
	}

	if val.Type() == dparval.ARRAY {
		overval := val.Value()
		switch overval := overval.(type) {
		case []interface{}:
			// FIXME major cleanup after full converstion to dparval
			// over expression evaluted to array
			// now walk the array and join
			for _, v := range overval {
				itemValue := item.Value()
				newValue := map[string]interface{}{}
				switch itemValue := itemValue.(type) {
				case map[string]interface{}:
					for itemK, itemV := range itemValue {
						newValue[itemK] = itemV
					}
					newValue[this.As] = v
				}
				itemMetaValue := item.Meta()
				itemMetaData, err := itemMetaValue.Path("meta")
				if err != nil {
					this.supportChannel <- query.NewError(err, "Internal Error")
					return false
				}
				finalItem := dparval.NewObjectValue(newValue)
				finalItem.AddMeta("meta", itemMetaData)
				this.itemChannel <- finalItem
			}
		}
	}

	return true
}
