//  Copyright (c) 2013 Couchbase, Inc.
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

package catalog

// Will be moved to a shared package
type Error error

// Will be moved to a shared package
type Item interface {
}

type Store interface {
	Catalog() (*Catalog, Error)
}

type Catalog interface {
	Buckets() (map[string]*Bucket, Error)
}

type Bucket interface {
	Name() string
	Count() (int64, Error) // why is this needed?
	AccessPaths() ([]*Scanner, Error)
	Fetch(id string) (*Item, Error)
}

type IndexStatistics interface {
	Count() (int64, Error)
	Min() (*Item, Error)
	Max() (*Item, Error)
	DistinctCount(int64, Error)
	Bins() ([]*Bin, Error)
}

type Bin interface {
	Count() (int64, Error)
	Min() (*Item, Error)
	Max() (*Item, Error)
	DistinctCount(int64, Error)
}

type ItemChannel chan *Item

type Scanner interface {
	Channel() (ItemChannel, Error)
	SetChannel(ItemChannel)
}

type FullScanner interface {
	Scanner
}

type Direction int

const (
	ASC  Direction = 1
	DESC           = 2
)

type RangeScanner interface {
	Scanner
	Key() []string
	Direction() Direction
	Statistics() (*IndexStatistics, Error)
}

// Couchbase view indexes
type ViewScanner interface {
	RangeScanner
}

// Declarative btree indexes
type IndexScanner interface {
	RangeScanner
}

// Full text search
type SearchScanner interface {
	Scanner
}